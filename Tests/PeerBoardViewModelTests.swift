import XCTest
@testable import SignalBoard

@MainActor
final class PeerBoardViewModelTests: XCTestCase {
    func testStartUsesSanitizedDisplayName() {
        let service = MockPeerBoardService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let viewModel = PeerBoardViewModel(
            service: service,
            identityStore: IdentityStore(defaults: defaults)
        )

        viewModel.displayName = "  Riley  "
        viewModel.start()

        XCTAssertEqual(service.startedWithName, "Riley")
        XCTAssertTrue(viewModel.isRunning)
    }

    func testPostNoteSendsTrimmedDraftAndClearsComposer() throws {
        let service = MockPeerBoardService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let viewModel = PeerBoardViewModel(
            service: service,
            identityStore: IdentityStore(defaults: defaults)
        )

        viewModel.displayName = "Taylor"
        viewModel.start()
        viewModel.draftText = "  Bring extension cords  "

        viewModel.postNote()

        XCTAssertEqual(service.postedNotes.count, 1)
        XCTAssertEqual(service.postedNotes.first?.text, "Bring extension cords")
        XCTAssertEqual(service.postedNotes.first?.authorName, "Taylor")
        XCTAssertEqual(viewModel.draftText, "")
    }

    func testServiceEventsRefreshListsAndBoardNotes() {
        let service = MockPeerBoardService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let viewModel = PeerBoardViewModel(
            service: service,
            identityStore: IdentityStore(defaults: defaults)
        )

        let peer = PeerDevice(id: "Alex", displayName: "Alex", state: .connected)
        let note = BoardNote(text: "Shared update", authorName: "Alex", tint: .mint)

        service.emit(.connectedPeersChanged([peer]))
        service.emit(.notesChanged([note]))

        XCTAssertEqual(viewModel.connectedPeers, [peer])
        XCTAssertEqual(viewModel.notes, [note])
    }
}

private final class MockPeerBoardService: PeerBoardServicing {
    var isSupported = true
    var onEvent: ((PeerBoardServiceEvent) -> Void)?

    private(set) var startedWithName: String?
    private(set) var postedNotes: [BoardNote] = []

    func start(displayName: String) {
        startedWithName = displayName
        onEvent?(.sessionChanged(isRunning: true, localPeerName: displayName))
    }

    func stop() {
        onEvent?(.sessionChanged(isRunning: false, localPeerName: ""))
    }

    func invite(peerID: String) {}

    func post(note: BoardNote) throws {
        postedNotes.append(note)
        onEvent?(.notesChanged(postedNotes))
    }

    func emit(_ event: PeerBoardServiceEvent) {
        onEvent?(event)
    }
}
