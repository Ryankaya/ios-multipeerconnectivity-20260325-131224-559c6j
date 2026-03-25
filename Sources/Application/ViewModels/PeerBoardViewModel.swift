import Foundation

@MainActor
final class PeerBoardViewModel: ObservableObject {
    @Published var displayName: String
    @Published var draftText = ""
    @Published private(set) var discoveredPeers: [PeerDevice] = []
    @Published private(set) var connectedPeers: [PeerDevice] = []
    @Published private(set) var notes: [BoardNote] = []
    @Published private(set) var statusHeadline: String
    @Published private(set) var statusDetail: String
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?

    let isSupported: Bool

    private let service: PeerBoardServicing
    private let identityStore: IdentityStore

    init(service: PeerBoardServicing, identityStore: IdentityStore) {
        self.service = service
        self.identityStore = identityStore
        self.displayName = identityStore.loadDisplayName()
        self.isSupported = service.isSupported
        self.statusHeadline = service.isSupported ? "Ready for nearby collaboration" : "Nearby collaboration unavailable"
        self.statusDetail = service.isSupported
            ? "Go live to discover peers and sync a shared board."
            : "MultipeerConnectivity is unavailable in this environment."

        service.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    var composerHint: String {
        connectedPeers.isEmpty
            ? "Post notes locally first, then invite nearby peers to sync them live."
            : "Every new note is broadcast to connected peers in real time."
    }

    var canPost: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggleSession() {
        isRunning ? stop() : start()
    }

    func start() {
        guard isSupported else {
            return
        }

        let normalizedName = normalizedDisplayName()
        displayName = normalizedName
        identityStore.saveDisplayName(normalizedName)
        service.start(displayName: normalizedName)
    }

    func stop() {
        service.stop()
    }

    func invite(_ peer: PeerDevice) {
        service.invite(peerID: peer.id)
    }

    func postNote() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let tint = NoteTint.allCases[notes.count % NoteTint.allCases.count]
        let note = BoardNote(text: trimmed, authorName: normalizedDisplayName(), tint: tint)

        do {
            try service.post(note: note)
            draftText = ""
            statusHeadline = "Note posted"
            statusDetail = connectedPeers.isEmpty
                ? "Saved locally. Invite someone nearby to share it live."
                : "Broadcasting your update to \(connectedPeers.count) connected peer(s)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func handle(_ event: PeerBoardServiceEvent) {
        switch event {
        case let .sessionChanged(isRunning, localPeerName):
            self.isRunning = isRunning
            if !localPeerName.isEmpty {
                displayName = localPeerName
            }
        case let .discoveredPeersChanged(peers):
            discoveredPeers = peers
        case let .connectedPeersChanged(peers):
            connectedPeers = peers
        case let .notesChanged(notes):
            self.notes = notes
        case let .statusChanged(headline, detail):
            statusHeadline = headline
            statusDetail = detail
        case let .error(message):
            errorMessage = message
        }
    }

    private func normalizedDisplayName() -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Signal Board Host" : trimmed
    }
}
