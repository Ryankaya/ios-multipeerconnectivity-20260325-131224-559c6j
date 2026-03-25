import Foundation
import MultipeerConnectivity
import Network

final class MultipeerBoardService: NSObject, PeerBoardServicing {
    var onEvent: ((PeerBoardServiceEvent) -> Void)?
    var isSupported: Bool { true }

    private let workQueue = DispatchQueue(label: "com.ryankaya.signalboard.multipeer")
    private let serviceType = "peer-board"
    private let localNetworkAuthorizer = LocalNetworkAuthorizer()

    private var localPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var discoveredPeers: [MCPeerID] = []
    private var connectionStates: [String: MCSessionState] = [:]
    private var notes: [BoardNote] = []

    func start(displayName: String) {
        workQueue.async {
            self.stopLocked(shouldEmitStatus: false)
            self.emit(.statusChanged(
                headline: "Preparing nearby session",
                detail: "Checking local network access. iOS may show a permission prompt."
            ))

            let localName = Self.sanitizedPeerName(from: displayName)
            self.localNetworkAuthorizer.requestAuthorization(serviceType: self.serviceType) { [weak self] result in
                guard let self else {
                    return
                }

                self.workQueue.async {
                    switch result {
                    case .success:
                        self.beginSessionLocked(localName: localName)
                    case .failure(let error):
                        self.emit(.statusChanged(
                            headline: "Local network access needed",
                            detail: "Allow Signal Board to use the local network so nearby discovery can start."
                        ))
                        self.emit(.error(Self.errorMessage(for: error, activity: "Advertising")))
                    }
                }
            }
        }
    }

    func stop() {
        workQueue.async {
            self.stopLocked(shouldEmitStatus: true)
        }
    }

    func invite(peerID: String) {
        workQueue.async {
            guard let browser = self.browser, let session = self.session else {
                return
            }

            guard let peer = self.discoveredPeers.first(where: { $0.displayName == peerID }) else {
                self.emit(.error("That peer is no longer discoverable."))
                return
            }

            self.connectionStates[peer.displayName] = .connecting
            self.emitPeerListsLocked()
            browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
            self.emit(.statusChanged(
                headline: "Invitation sent",
                detail: "Waiting for \(peer.displayName) to accept."
            ))
        }
    }

    func post(note: BoardNote) throws {
        let payload = try Self.encode(PeerBoardPayload.noteAdded(note))

        workQueue.async {
            self.mergeNotesLocked([note])
            self.broadcastLocked(payload, to: self.session?.connectedPeers ?? [])
        }
    }

    private func stopLocked(shouldEmitStatus: Bool) {
        localNetworkAuthorizer.cancel()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        advertiser?.delegate = nil
        browser?.delegate = nil
        session?.delegate = nil

        advertiser = nil
        browser = nil
        session = nil
        localPeerID = nil
        discoveredPeers = []
        connectionStates = [:]

        emit(.sessionChanged(isRunning: false, localPeerName: ""))
        emitPeerListsLocked()

        if shouldEmitStatus {
            emit(.statusChanged(
                headline: "Session paused",
                detail: "Your notes stay local until you go live again."
            ))
        }
    }

    private func beginSessionLocked(localName: String) {
        let peerID = MCPeerID(displayName: localName)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["board": "signal"],
            serviceType: serviceType
        )
        advertiser.delegate = self

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self

        localPeerID = peerID
        self.session = session
        self.advertiser = advertiser
        self.browser = browser
        discoveredPeers = []
        connectionStates = [:]

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()

        emit(.sessionChanged(isRunning: true, localPeerName: localName))
        emit(.statusChanged(
            headline: "Nearby board is live",
            detail: "Browsing and advertising for nearby collaborators."
        ))
        emit(.notesChanged(sortedNotesLocked()))
        emitPeerListsLocked()
    }

    private func mergeNotesLocked(_ incomingNotes: [BoardNote]) {
        var byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        for note in incomingNotes {
            byID[note.id] = note
        }

        notes = Array(byID.values).sorted { $0.createdAt > $1.createdAt }
        emit(.notesChanged(notes))
    }

    private func sortedNotesLocked() -> [BoardNote] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    private func emitPeerListsLocked() {
        let discovered = discoveredPeers
            .map { peer in
                PeerDevice(
                    id: peer.displayName,
                    displayName: peer.displayName,
                    state: Self.peerState(from: connectionStates[peer.displayName] ?? .notConnected)
                )
            }
            .filter { $0.state != .connected }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let connected = session?.connectedPeers
            .map { PeerDevice(id: $0.displayName, displayName: $0.displayName, state: .connected) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending } ?? []

        emit(.discoveredPeersChanged(discovered))
        emit(.connectedPeersChanged(connected))
    }

    private func handleIncomingPayload(_ payload: PeerBoardPayload, from peerID: MCPeerID) {
        switch payload.kind {
        case .noteAdded:
            if let note = payload.note {
                mergeNotesLocked([note])
                emit(.statusChanged(
                    headline: "New note received",
                    detail: "\(peerID.displayName) added a fresh card to the board."
                ))
            }
        case .snapshot:
            mergeNotesLocked(payload.notes ?? [])
            emit(.statusChanged(
                headline: "Board synced",
                detail: "Imported the latest nearby notes from \(peerID.displayName)."
            ))
        }
    }

    private func broadcastLocked(_ data: Data, to peers: [MCPeerID]) {
        guard let session, !peers.isEmpty else {
            return
        }

        do {
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            emit(.error("Unable to sync with nearby peers: \(error.localizedDescription)"))
        }
    }

    private func sendSnapshotLocked(to peer: MCPeerID) {
        do {
            let payload = PeerBoardPayload.snapshot(sortedNotesLocked())
            let data = try Self.encode(payload)
            broadcastLocked(data, to: [peer])
        } catch {
            emit(.error("Unable to prepare a board snapshot: \(error.localizedDescription)"))
        }
    }

    private func emit(_ event: PeerBoardServiceEvent) {
        DispatchQueue.main.async {
            self.onEvent?(event)
        }
    }

    private static func sanitizedPeerName(from displayName: String) -> String {
        let cleaned = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        let fallback = cleaned.isEmpty ? "Signal Board Host" : cleaned
        return String(fallback.prefix(30))
    }

    private static func peerState(from state: MCSessionState) -> PeerDeviceState {
        switch state {
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .notConnected:
            return .available
        @unknown default:
            return .available
        }
    }

    private static func encode(_ payload: PeerBoardPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    private static func decode(_ data: Data) throws -> PeerBoardPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PeerBoardPayload.self, from: data)
    }

    private static func errorMessage(for error: Error, activity: String) -> String {
        let nsError = error as NSError

        if isLocalNetworkPermissionError(error) {
            return "Signal Board cannot start nearby sharing until iOS grants Local Network access. Tap Settings below and enable Local Network. If Signal Board still does not appear there, delete the app, reinstall it, and tap Go Live Nearby again to force the permission prompt."
        }

        return "\(activity) failed (\(nsError.domain) \(nsError.code)): \(nsError.localizedDescription)"
    }

    private static func isLocalNetworkPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NetService.errorDomain, nsError.code == -72008 {
            return true
        }

        if nsError.domain == "Network.NWError", localNetworkDNSFailureCodes.contains(nsError.code) {
            return true
        }

        if let nwError = error as? NWError, case .dns(let dnsError) = nwError {
            return localNetworkDNSFailureCodes.contains(Int(dnsError))
        }

        return false
    }

    private static let localNetworkDNSFailureCodes: Set<Int> = [
        -65555, // kDNSServiceErr_NoAuth
        -65570  // kDNSServiceErr_PolicyDenied
    ]
}

extension MultipeerBoardService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        emit(.error(Self.errorMessage(for: error, activity: "Advertising")))
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        workQueue.async {
            self.emit(.statusChanged(
                headline: "Incoming collaborator",
                detail: "\(peerID.displayName) is joining your shared board."
            ))
            invitationHandler(true, self.session)
        }
    }
}

extension MultipeerBoardService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        emit(.error(Self.errorMessage(for: error, activity: "Browsing")))
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        workQueue.async {
            guard peerID != self.localPeerID else {
                return
            }

            guard !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) else {
                return
            }

            self.discoveredPeers.append(peerID)
            self.emitPeerListsLocked()
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        workQueue.async {
            self.discoveredPeers.removeAll { $0 == peerID }
            self.connectionStates.removeValue(forKey: peerID.displayName)
            self.emitPeerListsLocked()
        }
    }
}

extension MultipeerBoardService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        workQueue.async {
            self.connectionStates[peerID.displayName] = state
            self.emitPeerListsLocked()

            switch state {
            case .connected:
                self.emit(.statusChanged(
                    headline: "Connected to \(peerID.displayName)",
                    detail: "Your board is now syncing live."
                ))
                self.sendSnapshotLocked(to: peerID)
            case .connecting:
                self.emit(.statusChanged(
                    headline: "Connecting",
                    detail: "Negotiating a secure session with \(peerID.displayName)."
                ))
            case .notConnected:
                self.emit(.statusChanged(
                    headline: "Peer disconnected",
                    detail: "\(peerID.displayName) left the live board."
                ))
            @unknown default:
                self.emit(.statusChanged(
                    headline: "Session changed",
                    detail: "A nearby peer changed connection state."
                ))
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        workQueue.async {
            do {
                let payload = try Self.decode(data)
                self.handleIncomingPayload(payload, from: peerID)
            } catch {
                self.emit(.error("Received an unreadable payload from \(peerID.displayName)."))
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}

    func session(
        _ session: MCSession,
        didReceiveCertificate certificate: [Any]?,
        fromPeer peerID: MCPeerID,
        certificateHandler: @escaping (Bool) -> Void
    ) {
        certificateHandler(true)
    }
}
