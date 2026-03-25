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

    func testLocalNetworkErrorOffersSettingsShortcut() {
        let service = MockPeerBoardService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let viewModel = PeerBoardViewModel(
            service: service,
            identityStore: IdentityStore(defaults: defaults)
        )

        service.emit(.error("Advertising failed because Signal Board does not currently have Bonjour/local network access."))

        XCTAssertTrue(viewModel.shouldOfferSettingsShortcut)
    }

    func testNoAuthNetworkErrorOffersSettingsShortcut() {
        let service = MockPeerBoardService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let viewModel = PeerBoardViewModel(
            service: service,
            identityStore: IdentityStore(defaults: defaults)
        )

        service.emit(.error("Advertising failed (Network.NWError -65555): The operation couldn't be completed. (Network.NWError error -65555 - NoAuth)"))

        XCTAssertTrue(viewModel.shouldOfferSettingsShortcut)
    }

    func testSnapshotExportAndImportRoundTripMergesNotes() {
        let serviceA = MockPeerBoardService()
        let defaultsA = UserDefaults(suiteName: UUID().uuidString)!
        let viewModelA = PeerBoardViewModel(
            service: serviceA,
            identityStore: IdentityStore(defaults: defaultsA)
        )

        viewModelA.displayName = "Avery"
        viewModelA.start()
        viewModelA.draftText = "Bring power strips"
        viewModelA.postNote()

        let serviceB = MockPeerBoardService()
        let defaultsB = UserDefaults(suiteName: UUID().uuidString)!
        let viewModelB = PeerBoardViewModel(
            service: serviceB,
            identityStore: IdentityStore(defaults: defaultsB)
        )

        viewModelB.displayName = "Jordan"
        viewModelB.start()
        viewModelB.draftText = "Bring snacks"
        viewModelB.postNote()

        let shareToken = viewModelA.snapshotShareText
        XCTAssertFalse(shareToken.isEmpty)

        viewModelB.importSnapshotText = shareToken
        viewModelB.importSnapshot()

        XCTAssertTrue(viewModelB.importSnapshotText.isEmpty)
        XCTAssertEqual(viewModelB.notes.count, 2)
        XCTAssertTrue(viewModelB.notes.contains { $0.text == "Bring power strips" })
        XCTAssertTrue(viewModelB.notes.contains { $0.text == "Bring snacks" })
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
