import SwiftUI

@main
struct SignalBoardApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            PeerBoardView(viewModel: container.makePeerBoardViewModel())
        }
    }
}
