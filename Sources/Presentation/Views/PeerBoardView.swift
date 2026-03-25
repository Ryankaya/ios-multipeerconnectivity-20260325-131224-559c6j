import SwiftUI
import UIKit

struct PeerBoardView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: PeerBoardViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    init(viewModel: PeerBoardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    composerCard
                    peersCard
                    fallbackSharingCard
                    boardSection
                }
                .padding(20)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("Signal Board")
        }
        .alert("Signal Board", isPresented: errorBinding) {
            if viewModel.shouldOfferSettingsShortcut {
                Button("Settings") {
                    openSettings()
                }
            }

            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nearby shared notes")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(Color.textPrimary)

                    Text(viewModel.statusHeadline)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)

                    Text(viewModel.statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                statusBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Display name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)

                TextField("Your nearby alias", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.controlInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.inputSurface)
                    )
            }

            HStack(spacing: 12) {
                metricCard(title: "Live peers", value: "\(viewModel.connectedPeers.count)")
                metricCard(title: "Nearby finds", value: "\(viewModel.discoveredPeers.count)")
                metricCard(title: "Board cards", value: "\(viewModel.notes.count)")
            }

            Button(action: viewModel.toggleSession) {
                Text(viewModel.isRunning ? "Pause Session" : "Go Live Nearby")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(viewModel.isRunning ? Color.controlInk : Color.sunrise)
                    )
                    .foregroundStyle(viewModel.isRunning ? Color.onControlInk : Color.onAccent)
            }
            .disabled(!viewModel.isSupported)
            .opacity(viewModel.isSupported ? 1 : 0.55)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.surface, Color.heroAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Compose a board card", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text(viewModel.composerHint)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            TextEditor(text: $viewModel.draftText)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.controlInk)
                .frame(minHeight: 130)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.inputSurface)
                )
                .scrollContentBackground(.hidden)

            Button(action: viewModel.postNote) {
                Label("Post Note", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.mintLeaf)
                    )
                    .foregroundStyle(Color.onAccent)
            }
            .disabled(!viewModel.canPost)
            .opacity(viewModel.canPost ? 1 : 0.55)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var peersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Nearby collaborators", systemImage: "person.3.sequence.fill")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            if viewModel.connectedPeers.isEmpty {
                Text("No live collaborators yet. Start your session, then invite someone on the same local network.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.connectedPeers) { peer in
                            peerChip(peer.displayName, color: .mintLeaf)
                        }
                    }
                }
            }

            Divider()

            if viewModel.discoveredPeers.isEmpty {
                Text("No discoverable peers are visible right now.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(viewModel.discoveredPeers) { peer in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.displayName)
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                            Text(peer.state == .connecting ? "Connecting..." : "Available to invite")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Button("Invite") {
                            viewModel.invite(peer)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.sunrise)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var fallbackSharingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("No-network board sharing", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text("If iOS blocks Local Network permission, share your board snapshot manually. One device exports a token, another device pastes and imports it.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 10) {
                ShareLink(item: viewModel.snapshotShareText) {
                    Label("Share Snapshot", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sunrise)
                .disabled(!viewModel.canShareSnapshot)

                Button {
                    copySnapshotToPasteboard()
                } label: {
                    Label("Copy Token", systemImage: "doc.on.doc.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canShareSnapshot)
            }

            TextEditor(text: $viewModel.importSnapshotText)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.controlInk)
                .frame(minHeight: 90)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.inputSurface)
                )
                .scrollContentBackground(.hidden)

            Button(action: viewModel.importSnapshot) {
                Label("Import Snapshot", systemImage: "square.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.sky)
                    )
                    .foregroundStyle(Color.onAccent)
            }
            .disabled(!viewModel.canImportSnapshot)
            .opacity(viewModel.canImportSnapshot ? 1 : 0.55)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Shared board", systemImage: "rectangle.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            if viewModel.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your board is empty.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Post the first note to seed the board, then invite nearby peers to turn it into a live collaboration wall.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(cardBackground)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.notes) { note in
                        noteCard(note)
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(viewModel.isRunning ? "LIVE" : "LOCAL")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(viewModel.isRunning ? Color.mintLeaf : Color.controlInk)
            )
            .foregroundStyle(viewModel.isRunning ? Color.onAccent : Color.onControlInk)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.metricSurface)
        )
    }

    private func peerChip(_ name: String, color: Color) -> some View {
        Text(name)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.95))
            )
            .foregroundStyle(Color.onAccent)
    }

    private func noteCard(_ note: BoardNote) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(note.authorName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.noteMeta)
                Spacer()
                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(Color.noteMeta)
            }

            Text(note.text)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.noteText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(minHeight: 160, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(note.tint.fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(settingsURL)
    }

    private func copySnapshotToPasteboard() {
        guard viewModel.canShareSnapshot else {
            return
        }

        UIPasteboard.general.string = viewModel.snapshotShareText
        viewModel.markSnapshotCopied()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.dismissError()
                }
            }
        )
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.canvasTop, Color.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.sunrise.opacity(0.18))
                .frame(width: 260)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.mintLeaf.opacity(0.18))
                .frame(width: 220)
                .offset(x: 150, y: 330)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.surfaceStroke, lineWidth: 1)
            )
    }
}

private extension NoteTint {
    var fillColor: Color {
        switch self {
        case .amber:
            return Color.sunrise
        case .mint:
            return Color.mintLeaf
        case .coral:
            return Color.coral
        case .sky:
            return Color.sky
        }
    }
}

private extension Color {
    static let canvasTop = adaptive(
        light: UIColor(red: 0.96, green: 0.92, blue: 0.83, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.11, blue: 0.14, alpha: 1)
    )
    static let canvasBottom = adaptive(
        light: UIColor(red: 0.87, green: 0.82, blue: 0.75, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 0.99, green: 0.97, blue: 0.92, alpha: 0.94),
        dark: UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 0.96)
    )
    static let heroAccent = adaptive(
        light: UIColor(red: 0.98, green: 0.87, blue: 0.76, alpha: 1),
        dark: UIColor(red: 0.23, green: 0.19, blue: 0.16, alpha: 1)
    )
    static let sunrise = adaptive(
        light: UIColor(red: 0.96, green: 0.74, blue: 0.41, alpha: 1),
        dark: UIColor(red: 0.63, green: 0.43, blue: 0.18, alpha: 1)
    )
    static let mintLeaf = adaptive(
        light: UIColor(red: 0.68, green: 0.85, blue: 0.71, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.42, blue: 0.31, alpha: 1)
    )
    static let coral = adaptive(
        light: UIColor(red: 0.93, green: 0.60, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.27, blue: 0.24, alpha: 1)
    )
    static let sky = adaptive(
        light: UIColor(red: 0.67, green: 0.82, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.34, blue: 0.47, alpha: 1)
    )
    static let inputSurface = adaptive(
        light: UIColor(white: 1.0, alpha: 0.82),
        dark: UIColor(red: 0.23, green: 0.24, blue: 0.27, alpha: 1)
    )
    static let metricSurface = adaptive(
        light: UIColor(white: 1.0, alpha: 0.72),
        dark: UIColor(red: 0.21, green: 0.22, blue: 0.25, alpha: 1)
    )
    static let surfaceStroke = adaptive(
        light: UIColor(white: 1.0, alpha: 0.40),
        dark: UIColor(white: 1.0, alpha: 0.10)
    )
    static let controlInk = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    )
    static let onControlInk = adaptive(
        light: UIColor(red: 0.99, green: 0.97, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    )
    static let onAccent = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    )
    static let textPrimary = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    )
    static let textSecondary = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 0.72),
        dark: UIColor(red: 0.90, green: 0.88, blue: 0.84, alpha: 1)
    )
    static let textTertiary = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 0.58),
        dark: UIColor(red: 0.76, green: 0.74, blue: 0.70, alpha: 1)
    )
    static let noteText = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.97, green: 0.95, blue: 0.92, alpha: 1)
    )
    static let noteMeta = adaptive(
        light: UIColor(red: 0.23, green: 0.20, blue: 0.18, alpha: 0.65),
        dark: UIColor(red: 0.92, green: 0.90, blue: 0.86, alpha: 0.78)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
