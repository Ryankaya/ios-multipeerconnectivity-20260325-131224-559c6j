import SwiftUI

struct PeerBoardView: View {
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
                    boardSection
                }
                .padding(20)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("Signal Board")
        }
        .alert("Signal Board", isPresented: errorBinding) {
            Button("OK") {
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
                        .foregroundStyle(Color.ink)

                    Text(viewModel.statusHeadline)
                        .font(.headline)
                        .foregroundStyle(Color.ink.opacity(0.9))

                    Text(viewModel.statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink.opacity(0.7))
                }

                Spacer()

                statusBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Display name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ink.opacity(0.7))

                TextField("Your nearby alias", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.78))
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
                            .fill(viewModel.isRunning ? Color.ink : Color.sunrise)
                    )
                    .foregroundStyle(viewModel.isRunning ? Color.paper : Color.ink)
            }
            .disabled(!viewModel.isSupported)
            .opacity(viewModel.isSupported ? 1 : 0.55)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.paper, Color.peach],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Compose a board card", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(Color.ink)

            Text(viewModel.composerHint)
                .font(.subheadline)
                .foregroundStyle(Color.ink.opacity(0.7))

            TextEditor(text: $viewModel.draftText)
                .frame(minHeight: 130)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.82))
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
                    .foregroundStyle(Color.ink)
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
                .foregroundStyle(Color.ink)

            if viewModel.connectedPeers.isEmpty {
                Text("No live collaborators yet. Start your session, then invite someone on the same local network.")
                    .font(.subheadline)
                    .foregroundStyle(Color.ink.opacity(0.7))
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
                    .foregroundStyle(Color.ink.opacity(0.7))
            } else {
                ForEach(viewModel.discoveredPeers) { peer in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.displayName)
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                            Text(peer.state == .connecting ? "Connecting..." : "Available to invite")
                                .font(.caption)
                                .foregroundStyle(Color.ink.opacity(0.65))
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

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Shared board", systemImage: "rectangle.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(Color.ink)

            if viewModel.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your board is empty.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text("Post the first note to seed the board, then invite nearby peers to turn it into a live collaboration wall.")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink.opacity(0.7))
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
                    .fill(viewModel.isRunning ? Color.mintLeaf : Color.ink)
            )
            .foregroundStyle(viewModel.isRunning ? Color.ink : Color.paper)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.ink.opacity(0.55))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
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
            .foregroundStyle(Color.ink)
    }

    private func noteCard(_ note: BoardNote) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(note.authorName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.ink.opacity(0.65))
                Spacer()
                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(Color.ink.opacity(0.55))
            }

            Text(note.text)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.ink)
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
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
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
            .fill(Color.paper.opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
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
    static let canvasTop = Color(red: 0.96, green: 0.92, blue: 0.83)
    static let canvasBottom = Color(red: 0.87, green: 0.82, blue: 0.75)
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let peach = Color(red: 0.98, green: 0.87, blue: 0.76)
    static let sunrise = Color(red: 0.96, green: 0.74, blue: 0.41)
    static let mintLeaf = Color(red: 0.68, green: 0.85, blue: 0.71)
    static let coral = Color(red: 0.93, green: 0.60, blue: 0.51)
    static let sky = Color(red: 0.67, green: 0.82, blue: 0.92)
    static let ink = Color(red: 0.23, green: 0.20, blue: 0.18)
}
