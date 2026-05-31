import SwiftUI
import UIKit

struct AddLyricsView: View {
    let onGenerate: () -> Void

    @EnvironmentObject private var queue: GenerationQueue
    @EnvironmentObject private var spotify: SpotifyManager

    // Persisted across sessions
    @SceneStorage("addLyrics.title")     private var title     = ""
    @SceneStorage("addLyrics.artist")    private var artist    = ""
    @SceneStorage("addLyrics.rawLyrics") private var rawLyrics = ""

    // Spotify search
    @State private var spotifyQuery          = ""
    @State private var spotifyResults: [SpotifyTrack] = []
    @State private var isSpotifySearching    = false
    @State private var spotifySearchTask: Task<Void, Never>?
    @State private var nowPlaying: SpotifyTrack?
    @State private var spotifyError: String?

    // Manual entry toggle
    @State private var showManual = false

    // Lyrics lookup
    @State private var isLyricsSearching    = false
    @State private var candidates: [LookupCandidate] = []
    @State private var lyricsError: String?
    @State private var selectedCandidateId: String?
    @State private var didLyricsSearch      = false

    @State private var selectedImageUrl: String?
    @State private var generateError: String?

    private let maxChars = 30_000

    private var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var canGenerate: Bool {
        hasTitle
            && !rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLyricsSearching
    }

    var body: some View {
        Form {
            // MARK: - Now Playing
            if let track = nowPlaying, !hasTitle {
                Section {
                    SpotifyResultRow(track: track) { selectTrack(track) }
                } header: {
                    Label("Now Playing", systemImage: "music.note")
                }
            }

            // MARK: - Search
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.body)

                    TextField("Search Spotify…", text: $spotifyQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onChange(of: spotifyQuery) { _, q in scheduleSearch(q) }

                    if isSpotifySearching {
                        ProgressView()
                    } else if !spotifyQuery.isEmpty {
                        Button {
                            spotifyQuery = ""
                            spotifyResults = []
                            spotifyError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(spotifyResults) { track in
                    SpotifyResultRow(track: track) { selectTrack(track) }
                }

                if !spotifyQuery.isEmpty || !spotifyResults.isEmpty {
                    if !showManual {
                        Button("Can't find it? Enter manually") {
                            showManual = true
                            spotifyQuery = ""
                            spotifyResults = []
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }

                if let err = spotifyError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                if !spotify.isAuthorized {
                    Button { Task { await connectSpotify() } } label: {
                        Label("Connect Spotify", systemImage: "music.note")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // MARK: - Manual entry
            if showManual {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Artist (optional)", text: $artist)
                        .textInputAutocapitalization(.words)

                    Button {
                        Task { await searchLyrics() }
                    } label: {
                        HStack {
                            if isLyricsSearching {
                                ProgressView().padding(.trailing, 4)
                                Text("Searching…")
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find lyrics online")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!hasTitle || isLyricsSearching)
                } header: {
                    HStack {
                        Text("Manual Entry")
                        Spacer()
                        Button("Cancel") {
                            showManual = false
                            title = ""; artist = ""; selectedImageUrl = nil
                            candidates = []; selectedCandidateId = nil
                            lyricsError = nil; didLyricsSearch = false
                        }
                        .font(.caption)
                    }
                }
            }

            // MARK: - Selected track
            if hasTitle && !showManual {
                Section {
                    HStack(spacing: 12) {
                        AlbumThumbnail(url: selectedImageUrl, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.subheadline.weight(.semibold))
                            if !artist.isEmpty {
                                Text(artist).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            title = ""; artist = ""; selectedImageUrl = nil
                            candidates = []; selectedCandidateId = nil
                            rawLyrics = ""; lyricsError = nil; didLyricsSearch = false
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if isLyricsSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Finding lyrics…").foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }

                    if let err = lyricsError {
                        Text(err).font(.callout).foregroundStyle(.red)
                    }

                    if didLyricsSearch && !isLyricsSearching && candidates.isEmpty && lyricsError == nil {
                        Text("No lyrics found — paste them below.")
                            .font(.callout).foregroundStyle(.secondary)
                    }

                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate, isSelected: candidate.id == selectedCandidateId)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCandidateId = candidate.id
                                rawLyrics = candidate.devanagari
                            }
                    }
                } header: {
                    Text("Song")
                }
            }

            // MARK: - Lyrics
            if hasTitle {
                Section {
                    TextEditor(text: $rawLyrics)
                        .frame(height: 220)
                        .font(.body)
                    HStack {
                        Spacer()
                        Text("\(rawLyrics.count) / \(maxChars)")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                } header: {
                    Text("Lyrics")
                } footer: {
                    Text("Tap a candidate above or paste raw lyrics.")
                }
            }

            if let err = generateError {
                Section {
                    Text(err).foregroundStyle(.red).font(.callout)
                }
            }
        }
        .navigationTitle("Add Song")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard spotify.isAuthorized else { return }
            nowPlaying = try? await spotify.currentlyPlaying()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Generate") { Task { await submit() } }
                    .fontWeight(.semibold)
                    .disabled(!canGenerate)
            }
        }
    }

    // MARK: - Actions

    private func selectTrack(_ track: SpotifyTrack) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        title = track.name
        artist = track.artist
        selectedImageUrl = track.imageUrl
        showManual = false
        spotifyQuery = ""
        spotifyResults = []
        spotifyError = nil
        Task { await searchLyrics() }
    }

    private func scheduleSearch(_ q: String) {
        spotifySearchTask?.cancel()
        spotifyError = nil
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            spotifyResults = []; return
        }
        spotifySearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await runSpotifySearch(q)
        }
    }

    private func runSpotifySearch(_ q: String) async {
        isSpotifySearching = true
        defer { isSpotifySearching = false }
        do {
            let r = try await APIClient.shared.spotifySearch(query: q)
            guard !Task.isCancelled else { return }
            spotifyResults = r
        } catch {
            guard !Task.isCancelled else { return }
            spotifyError = error.localizedDescription
        }
    }

    private func searchLyrics() async {
        lyricsError = nil
        candidates = []
        selectedCandidateId = nil
        isLyricsSearching = true
        didLyricsSearch = true
        defer { isLyricsSearching = false }
        do {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let results = try await APIClient.shared.lookupLyrics(title: t, artist: a.isEmpty ? nil : a)
            candidates = results
            if results.count == 1 {
                selectedCandidateId = results[0].id
                rawLyrics = results[0].devanagari
            }
        } catch {
            lyricsError = error.localizedDescription
        }
    }

    private func connectSpotify() async {
        spotifyError = nil
        do { try await spotify.authenticate() }
        catch { spotifyError = error.localizedDescription }
    }

    private func clearForm() {
        title = ""; artist = ""; rawLyrics = ""; selectedImageUrl = nil
        candidates = []; selectedCandidateId = nil
        lyricsError = nil; didLyricsSearch = false
        showManual = false; spotifyQuery = ""; spotifyResults = []
        generateError = nil
    }

    private func submit() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { generateError = "Title is required"; return }
        guard !l.isEmpty else { generateError = "Please enter lyrics or pick a candidate"; return }
        let img = selectedImageUrl
        queue.start(rawLyrics: l, titleHint: t, artistHint: a, imageUrl: img, onComplete: { _ in })
        clearForm()
        onGenerate()
    }
}

// MARK: - Spotify result row

private struct SpotifyResultRow: View {
    let track: SpotifyTrack
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                AlbumThumbnail(url: track.imageUrl, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Candidate row

private struct CandidateRow: View {
    let candidate: LookupCandidate
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title).font(.subheadline.weight(.semibold))
                    if !candidate.artist.isEmpty {
                        Text(candidate.artist).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ConfidenceBadge(level: candidate.confidence)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            Text(previewLines(candidate.devanagari))
                .font(.callout).foregroundStyle(.secondary).lineLimit(3)
            if !candidate.notes.isEmpty {
                Text(candidate.notes).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func previewLines(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: true).prefix(3).joined(separator: "\n")
    }
}

private struct ConfidenceBadge: View {
    let level: String
    private var color: Color {
        switch level { case "high": .green; case "medium": .orange; case "low": .red; default: .gray }
    }
    var body: some View {
        Text(level.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
