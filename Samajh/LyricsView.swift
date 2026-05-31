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

    func updateLine(songId: String, lineId: String, fields: LineUpdateRequest) async throws {
        try await APIClient.shared.updateLine(songId: songId, lineId: lineId, fields: fields)
        lesson = try await APIClient.shared.getSong(songId: songId, includeTokens: true)
    }

    @Published var retranslatingLineId: String?

    func beginRetranslateLine(songId: String, lineId: String, feedback: String?) {
        retranslatingLineId = lineId
        Task {
            defer { retranslatingLineId = nil }
            guard (try? await APIClient.shared.retranslateLine(songId: songId, lineId: lineId, feedback: feedback)) != nil else { return }
            lesson = try? await APIClient.shared.getSong(songId: songId, includeTokens: true)
        }
    }

    func insertInstrumental(songId: String, beforeLineId: String) async throws {
        try await APIClient.shared.insertInstrumental(songId: songId, beforeLineId: beforeLineId)
        lesson = try await APIClient.shared.getSong(songId: songId, includeTokens: true)
    }

    func deleteLine(songId: String, lineId: String) async throws {
        try await APIClient.shared.deleteLine(songId: songId, lineId: lineId)
        lesson = try await APIClient.shared.getSong(songId: songId, includeTokens: true)
    }

    func deleteSong(songId: String) async throws {
        try await APIClient.shared.deleteSong(songId: songId)
    }
}

struct LyricsView: View {
    let songId: String
    var imageUrl: String? = nil
    @StateObject private var vm = LyricsViewModel()

    @AppStorage("showNative") private var showNative = false
    @AppStorage("showWordByWord") private var showWordByWord = false
    @AppStorage("showDirect") private var showDirect = false
    @AppStorage("showNatural") private var showNatural = true
    @State private var showNavBarTitle = false
    @State private var activeTokenItem: ActiveTokenItem?
    @State private var editingLine: LyricLineModel?
    @State private var showSongRetranslate = false
    @State private var showDeleteConfirm = false
    @State private var showFlashcards = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var queue: GenerationQueue

    private struct ActiveTokenItem: Identifiable {
        let id = "active"
        var token: LyricToken
    }

    var body: some View {
        mainContent
            .navigationTitle(vm.lesson?.title ?? "")  // drives back-button label in child views
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Title fades in only once the content header scrolls away
                ToolbarItem(placement: .principal) {
                    Text(vm.lesson?.title ?? "")
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(showNavBarTitle ? 1 : 0)
                        .animation(SamajhMotion.fade, value: showNavBarTitle)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Study Flashcards") { showFlashcards = true }
                            .disabled(vm.lesson == nil)
                        Button("Retranslate Song…") { showSongRetranslate = true }
                        Divider()
                        Button("Delete Song", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $showFlashcards) {
                if let lesson = vm.lesson { FlashcardView(lesson: lesson) }
            }
            .alert("Delete this song?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { try? await vm.deleteSong(songId: songId); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    ToggleChip(label: "Native", isOn: $showNative)
                    ToggleChip(label: "Word", isOn: $showWordByWord)
                    ToggleChip(label: "Direct", isOn: $showDirect)
                    ToggleChip(label: "Natural", isOn: $showNatural)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.samajhBackgroundSecondary.opacity(0.95))
            }
            .toolbar(.hidden, for: .tabBar)
            .task { await vm.load(songId: songId) }
            .sheet(item: $activeTokenItem) { item in
                TokenSheet(token: item.token)
                    .presentationDetents([.fraction(0.25), .medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
            }
            .sheet(item: $editingLine) { line in
                LineEditSheet(
                    songId: songId, line: line, vm: vm,
                    onRetranslate: { feedback in
                        vm.beginRetranslateLine(songId: songId, lineId: line.lineId, feedback: feedback)
                    }
                )
            }
            .sheet(isPresented: $showSongRetranslate) {
                SongRetranslateSheet { feedback in
                    queue.retranslateSong(songId: songId, title: vm.lesson?.title ?? songId, imageUrl: imageUrl, feedback: feedback)
                    dismiss()
                }
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text("Couldn't load song").font(.headline)
                    Text(error).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await vm.load(songId: songId) } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let lesson = vm.lesson {
                content(for: lesson)
            }
        }
    }

    @ViewBuilder
    private func content(for lesson: LyricLesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(alignment: .center, spacing: 14) {
                    AlbumThumbnail(url: imageUrl, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lesson.title)
                            .font(.custom(SamajhFont.interBold, size: 22))
                            .foregroundStyle(Color.samajhTextPrimary)
                        if let artist = lesson.source?.artist, !artist.isEmpty {
                            Text(artist)
                                .font(.custom(SamajhFont.interRegular, size: 15))
                                .foregroundStyle(Color.samajhTextSecondary)
                        }
                    }
                }
                .padding(.top, 12)

                ForEach(lesson.sections) { section in
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(section.lines) { line in
                            LyricLineRow(
                                line: line,
                                showNative: showNative,
                                showWordByWord: showWordByWord,
                                showDirect: showDirect,
                                showNatural: showNatural,
                                isFavorite: favorites.isFavorite(lineId: line.lineId, songId: songId),
                                isRetranslating: vm.retranslatingLineId == line.lineId,
                                onTokenTap: { token in
                                    activeTokenItem = ActiveTokenItem(token: token)
                                },
                                onEdit: {
                                    editingLine = line
                                },
                                onInsertInstrumental: {
                                    Task { try? await vm.insertInstrumental(songId: songId, beforeLineId: line.lineId) }
                                },
                                onDeleteLine: {
                                    Task { try? await vm.deleteLine(songId: songId, lineId: line.lineId) }
                                },
                                onToggleFavorite: {
                                    let fl = FavoriteLine(
                                        lineId: line.lineId,
                                        songId: songId,
                                        songTitle: lesson.title,
                                        target: line.text.target,
                                        roman: line.text.roman,
                                        natural: line.text.natural
                                    )
                                    favorites.toggle(line: fl)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                activeTokenItem = nil
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y > 30
        } action: { _, pastHeader in
            withAnimation(SamajhMotion.fade) {
                showNavBarTitle = pastHeader
            }
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
                .font(.custom(SamajhFont.interMedium, size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isOn ? Color.samajhGold.opacity(0.18) : Color.samajhSurfaceElevated)
                )
                .foregroundStyle(isOn ? Color.samajhGold : Color.samajhTextMuted)
        }
        .buttonStyle(.plain)
    }
}

private struct LyricLineRow: View {
    let line: LyricLineModel
    let showNative: Bool
    let showWordByWord: Bool
    let showDirect: Bool
    let showNatural: Bool
    let isFavorite: Bool
    let isRetranslating: Bool
    let onTokenTap: (LyricToken) -> Void
    let onEdit: () -> Void
    let onInsertInstrumental: () -> Void
    let onDeleteLine: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        if line.isInstrumental == true {
            instrumentalRow
        } else if isRetranslating {
            HStack {
                lyricRow.opacity(0.4)
                Spacer()
                ProgressView()
            }
        } else {
            lyricRow
                .contextMenu {
                    Button { onToggleFavorite() } label: {
                        Label(
                            isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: isFavorite ? "heart.slash" : "heart"
                        )
                    }
                    Divider()
                    Button { onEdit() } label: {
                        Label("Edit Translation", systemImage: "pencil")
                    }
                    Button { onInsertInstrumental() } label: {
                        Label("Add Instrumental Before", systemImage: "music.note")
                    }
                    Divider()
                    Button(role: .destructive) { onDeleteLine() } label: {
                        Label("Remove Line", systemImage: "trash")
                    }
                }
        }
    }

    private var instrumentalRow: some View {
        Text("♩  ♪  ♫  ♬  ♩  ♪  ♫  ♬")
            .font(.body)
            .foregroundStyle(Color.accentColor.opacity(0.5))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .contextMenu {
                Button(role: .destructive) {
                    onDeleteLine()
                } label: {
                    Label("Remove Instrumental", systemImage: "trash")
                }
            }
    }

    private var lyricRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                if showNative {
                    Text(line.text.target)
                        .font(.custom(SamajhFont.notoDevanagari, size: 36))
                        .foregroundStyle(Color.samajhTextPrimary)
                        .lineSpacing(4)
                        .padding(.bottom, -8)
                }

                romanLine

                if showWordByWord, let s = line.text.wordByWord, !s.isEmpty {
                    Text(s)
                        .font(.custom(SamajhFont.interRegular, size: 14))
                        .foregroundStyle(Color.samajhTextMuted)
                        .padding(.top, 2)
                }
                if showDirect, let s = line.text.direct, !s.isEmpty {
                    Text(s)
                        .font(.custom(SamajhFont.interRegular, size: 20))
                        .foregroundStyle(Color.samajhTextSecondary)
                }
                if showNatural, let s = line.text.natural, !s.isEmpty {
                    Text(s)
                        .font(.custom(SamajhFont.interRegular, size: 22))
                        .foregroundStyle(Color.samajhTextPrimary)
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            Button {
                TTSPlayer.shared.speak(line.text.target)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var romanLine: some View {
        let pairs = Self.alignWordsToTokens(
            roman: line.text.roman,
            tokens: line.tokens ?? []
        )
        return WrapHStack(spacing: 4, lineSpacing: 4) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                if let token = pair.token {
                    Button {
                        onTokenTap(token)
                    } label: {
                        Text(pair.word)
                            .font(.custom(SamajhFont.interMedium, size: 19))
                            .foregroundStyle(Color.samajhGold)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(pair.word)
                        .font(.custom(SamajhFont.interRegular, size: 19))
                        .foregroundStyle(Color.samajhGold)
                }
            }
        }
    }

    private static func alignWordsToTokens(
        roman: String,
        tokens: [LyricToken]
    ) -> [(word: String, token: LyricToken?)] {
        let words = roman.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var result: [(word: String, token: LyricToken?)] = []
        var tokenIdx = 0

        func normalize(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter || $0.isNumber }
        }

        for word in words {
            let normWord = normalize(word)
            if normWord.isEmpty {
                // pure punctuation — render as-is, no token
                result.append((word, nil))
            } else if tokenIdx < tokens.count && normalize(tokens[tokenIdx].roman) == normWord {
                result.append((word, tokens[tokenIdx]))
                tokenIdx += 1
            } else {
                // word present in roman but no matching token (mismatch) — still render
                result.append((word, nil))
            }
        }
        return result
    }
}

private struct TokenSheet: View {
    let token: LyricToken

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(token.surface)
                    .font(.custom(SamajhFont.notoDevanagari, size: 36))
                    .foregroundStyle(Color.samajhTextPrimary)
                Text(token.roman)
                    .font(.custom(SamajhFont.interRegular, size: 20))
                    .foregroundStyle(Color.samajhTextRoman)
                Spacer()
                Button {
                    TTSPlayer.shared.speak(token.surface)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.body)
                        .foregroundStyle(Color.samajhTextMuted)
                }
                .buttonStyle(.plain)
            }
            Text(token.gloss)
                .font(.custom(SamajhFont.interRegular, size: 18))
                .foregroundStyle(Color.samajhTextSecondary)
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

// MARK: - Line Edit Sheet

private struct LineEditSheet: View {
    let songId: String
    let line: LyricLineModel
    @ObservedObject var vm: LyricsViewModel
    let onRetranslate: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var roman: String
    @State private var wordByWord: String
    @State private var direct: String
    @State private var natural: String
    @State private var feedback: String = ""
    @State private var isBusy = false
    @State private var errorMsg: String?
    @State private var mode: Mode = .manual

    enum Mode { case manual, retranslate }

    init(songId: String, line: LyricLineModel, vm: LyricsViewModel, onRetranslate: @escaping (String?) -> Void) {
        self.songId = songId
        self.line = line
        self.vm = vm
        self.onRetranslate = onRetranslate
        _roman = State(initialValue: line.text.roman)
        _wordByWord = State(initialValue: line.text.wordByWord ?? "")
        _direct = State(initialValue: line.text.direct ?? "")
        _natural = State(initialValue: line.text.natural ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Original") {
                    Text(line.text.target)
                        .font(.title3)
                }

                Picker("Mode", selection: $mode) {
                    Text("Edit manually").tag(Mode.manual)
                    Text("Retranslate with AI").tag(Mode.retranslate)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if mode == .manual {
                    Section("Roman") {
                        TextField("Romanization", text: $roman)
                    }
                    Section("Word by Word") {
                        TextField("Word-by-word gloss", text: $wordByWord)
                    }
                    Section("Direct") {
                        TextField("Direct translation", text: $direct, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    Section("Natural") {
                        TextField("Natural translation", text: $natural, axis: .vertical)
                            .lineLimit(2...4)
                    }
                } else {
                    Section("Feedback (optional)") {
                        TextField("e.g. 'keep it more literal'", text: $feedback, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if let msg = errorMsg {
                    Section {
                        Text(msg).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Edit Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isBusy {
                        ProgressView()
                    } else {
                        Button(mode == .manual ? "Save" : "Retranslate") {
                            if mode == .retranslate {
                                onRetranslate(feedback.isEmpty ? nil : feedback)
                                dismiss()
                            } else {
                                Task { await save() }
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isBusy = true
        errorMsg = nil
        defer { isBusy = false }
        do {
            let fields = LineUpdateRequest(
                roman: roman.isEmpty ? nil : roman,
                wordByWord: wordByWord.isEmpty ? nil : wordByWord,
                direct: direct.isEmpty ? nil : direct,
                natural: natural.isEmpty ? nil : natural
            )
            try await vm.updateLine(songId: songId, lineId: line.lineId, fields: fields)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Song Retranslate Sheet

private struct SongRetranslateSheet: View {
    let onConfirm: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedback: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Re-runs the AI translation on the whole song and saves it as a new version. Runs in the background.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("Feedback (optional)") {
                    TextField("e.g. 'this is Urdu, not Hindi'", text: $feedback, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Retranslate Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Retranslate") {
                        onConfirm(feedback.isEmpty ? nil : feedback)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
