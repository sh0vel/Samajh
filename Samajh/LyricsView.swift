import SwiftUI

@MainActor
final class LyricsViewModel: ObservableObject {
    @Published var lesson: LyricLesson?
    @Published var isLoading = false
    @Published var error: String?

    func load(songId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            lesson = try await APIClient.shared.getSong(songId: songId, includeTokens: true)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct LyricsView: View {
    let songId: String
    @StateObject private var vm = LyricsViewModel()

    @State private var showHindi = false
    @State private var showWordByWord = false
    @State private var showDirect = false
    @State private var showNatural = false
    @State private var activeTokenItem: ActiveTokenItem?

    private struct ActiveTokenItem: Identifiable {
        let id = "active"
        var token: LyricToken
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text("Couldn't load song")
                        .font(.headline)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.load(songId: songId) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let lesson = vm.lesson {
                content(for: lesson)
            }
        }
        .navigationTitle(vm.lesson?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                ToggleChip(label: "हिंदी", isOn: $showHindi)
                ToggleChip(label: "Word", isOn: $showWordByWord)
                ToggleChip(label: "Direct", isOn: $showDirect)
                ToggleChip(label: "Natural", isOn: $showNatural)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .task {
            await vm.load(songId: songId)
        }
        .sheet(item: $activeTokenItem) { item in
            TokenSheet(token: item.token)
                .presentationDetents([.fraction(0.25), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
    }

    @ViewBuilder
    private func content(for lesson: LyricLesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.title2.bold())
                    if let artist = lesson.source?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                ForEach(lesson.sections) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        if let label = section.label, !label.isEmpty {
                            Text(label.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .tracking(1.2)
                        }
                        ForEach(section.lines) { line in
                            LyricLineRow(
                                line: line,
                                showHindi: showHindi,
                                showWordByWord: showWordByWord,
                                showDirect: showDirect,
                                showNatural: showNatural,
                                onTokenTap: { token in
                                    activeTokenItem = ActiveTokenItem(token: token)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ToggleChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct LyricLineRow: View {
    let line: LyricLineModel
    let showHindi: Bool
    let showWordByWord: Bool
    let showDirect: Bool
    let showNatural: Bool
    let onTokenTap: (LyricToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showHindi {
                Text(line.text.target)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            romanLine

            if showWordByWord, let s = line.text.wordByWord, !s.isEmpty {
                Text(s)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if showDirect, let s = line.text.direct, !s.isEmpty {
                Text(s)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
            if showNatural, let s = line.text.natural, !s.isEmpty {
                Text(s)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var romanLine: some View {
        let words = line.text.roman.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let tokens = line.tokens ?? []
        return WrapHStack(spacing: 4, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                if word.isEmpty {
                    EmptyView()
                } else if idx < tokens.count {
                    let token = tokens[idx]
                    Button {
                        onTokenTap(token)
                    } label: {
                        Text(word)
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                            .underline(true, pattern: .dot)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(word)
                        .font(.body)
                }
            }
        }
    }
}

private struct TokenSheet: View {
    let token: LyricToken

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(token.surface)
                    .font(.title.bold())
                Text(token.roman)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text(token.gloss)
                .font(.body)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        _FlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content()
        }
    }
}

private struct _FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.minX + maxWidth {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
