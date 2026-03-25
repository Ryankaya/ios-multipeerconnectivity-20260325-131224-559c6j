import Foundation

struct PeerBoardPayload: Codable {
    let kind: PeerBoardPayloadKind
    let note: BoardNote?
    let notes: [BoardNote]?

    static func noteAdded(_ note: BoardNote) -> PeerBoardPayload {
        PeerBoardPayload(kind: .noteAdded, note: note, notes: nil)
    }

    static func snapshot(_ notes: [BoardNote]) -> PeerBoardPayload {
        PeerBoardPayload(kind: .snapshot, note: nil, notes: notes)
    }
}

enum PeerBoardPayloadKind: String, Codable {
    case noteAdded
    case snapshot
}
