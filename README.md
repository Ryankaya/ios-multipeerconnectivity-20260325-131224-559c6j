# Signal Board (`ios-multipeerconnectivity-20260325-131224-559c6j`)

Signal Board is a SwiftUI iOS app that turns nearby devices into a lightweight shared note board. It demonstrates **MultipeerConnectivity** in a production-style MVVM architecture, including peer discovery, invitations, automatic session acceptance, note syncing, and graceful offline behavior.

## Feature Used

- `MultipeerConnectivity` for nearby discovery, invitations, encrypted sessions, and live payload exchange.

## Architecture (MVVM)

- `Sources/Domain`: note models, peer models, and the service protocol.
- `Sources/Infrastructure`: `MultipeerBoardService` plus a small identity store.
- `Sources/Application`: `PeerBoardViewModel` orchestration and presentation state.
- `Sources/Presentation`: SwiftUI composition for the collaboration dashboard.
- `Sources/App`: dependency wiring through `AppContainer`.

## What It Does

- Lets the user choose a display name and go live on the local network.
- Browses for nearby peers and sends explicit invitations.
- Automatically accepts inbound invitations for low-friction collaboration.
- Syncs sticky-note style posts across connected peers using JSON payloads.
- Keeps local notes available even when no peers are connected.
- Includes a no-network fallback: export/import board snapshots as shareable tokens.
- Includes a testable view model with a mock collaboration service.

## Build

```bash
xcodegen generate
xcodebuild -project ios-multipeerconnectivity-20260325-131224-559c6j.xcodeproj -scheme SignalBoard -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Apple Documentation Used

- https://developer.apple.com/documentation/multipeerconnectivity
- https://developer.apple.com/documentation/multipeerconnectivity/mcsession
- https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyserviceadvertiser
- https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyservicebrowser
