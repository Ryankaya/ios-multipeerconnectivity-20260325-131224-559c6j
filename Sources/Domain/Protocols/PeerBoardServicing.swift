import Foundation

protocol PeerBoardServicing: AnyObject {
    var isSupported: Bool { get }
    var onEvent: ((PeerBoardServiceEvent) -> Void)? { get set }

    func start(displayName: String)
    func stop()
    func invite(peerID: String)
    func post(note: BoardNote) throws
}

enum PeerBoardServiceEvent: Equatable {
    case sessionChanged(isRunning: Bool, localPeerName: String)
    case discoveredPeersChanged([PeerDevice])
    case connectedPeersChanged([PeerDevice])
    case notesChanged([BoardNote])
    case statusChanged(headline: String, detail: String)
    case error(String)
}
