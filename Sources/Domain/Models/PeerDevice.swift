import Foundation

struct PeerDevice: Identifiable, Equatable {
    let id: String
    let displayName: String
    let state: PeerDeviceState
}

enum PeerDeviceState: String, Equatable {
    case available
    case connecting
    case connected
}
