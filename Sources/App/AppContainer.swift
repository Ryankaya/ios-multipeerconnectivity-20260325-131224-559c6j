import Foundation

@MainActor
struct AppContainer {
    let makePeerBoardViewModel: () -> PeerBoardViewModel

    static let live: AppContainer = {
        let identityStore = IdentityStore()
        let service = MultipeerBoardService()
        return AppContainer {
            PeerBoardViewModel(
                service: service,
                identityStore: identityStore
            )
        }
    }()
}
