import SwiftUI

struct AddLyricsView: View {
    let onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @SceneStorage("addLyrics.title") private var title = ""
    @SceneStorage("addLyrics.artist") private var artist = ""
    @SceneStorage("addLyrics.rawLyrics") private var rawLyrics = ""

    @State private var isSearching = false
    @State private var searchError: String?
    @State private var candidates: [LookupCandidate] = []
    @State private var didSearch = false
    @State private var selectedCandidateId: String?

    @EnvironmentObject private var queue: GenerationQueue
    @State private var generateError: String?

    private let maxChars = 30_000

    private var canSearch: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching
    }

    private var canGenerate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSearching
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .disabled(isSearching)
                    TextField("Artist (optional)", text: $artist)
                        .textInputAutocapitalization(.words)
                        .disabled(isSearching)
                } header: {
                    Text("Song")
                } footer: {
                    Text("Title is required. Add the artist for better matches.")
                }

                Section {
                    Button {
                        Task { await search() }
                    } label: {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("Searching…")
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find lyrics online")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSearch)

                    if let searchError {
                        Text(searchError)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }

                    if didSearch && !isSearching && candidates.isEmpty && searchError == nil {
                        Text("No lyrics found. Paste them manually below.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(candidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: candidate.id == selectedCandidateId
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCandidateId = candidate.id
                            rawLyrics = candidate.devanagari
                        }
                    }
                } header: {
                    Text("Auto-find")
                }

                Section {
                    TextEditor(text: $rawLyrics)
                        .frame(height: 260)
                        .font(.body)
                    HStack {
                        Spacer()
                        Text("\(rawLyrics.count) / \(maxChars)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Text("Hindi Lyrics")
                } footer: {
                    Text("Tap a candidate above or paste raw Devanagari.")
                }

                if let generateError {
                    Section {
                        Text(generateError)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Add Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { clearAndDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Generate") {
                        Task { await submit() }
                    }
                    .disabled(!canGenerate)
                }
            }
        }
    }

    private func clearAndDismiss() {
        title = ""
        artist = ""
        rawLyrics = ""
        dismiss()
    }

    private func search() async {
        searchError = nil
        candidates = []
        selectedCandidateId = nil
        isSearching = true
        didSearch = true
        defer { isSearching = false }

        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let results = try await APIClient.shared.lookupLyrics(
                title: trimmedTitle,
                artist: trimmedArtist.isEmpty ? nil : trimmedArtist
            )
            candidates = results
            if results.count == 1 {
                selectedCandidateId = results[0].id
                rawLyrics = results[0].devanagari
            }
        } catch {
            searchError = error.localizedDescription
        }
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLyrics = rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            generateError = "Title is required"
            return
        }
        guard !trimmedLyrics.isEmpty else {
            generateError = "Please enter lyrics or pick a candidate"
            return
        }
        clearAndDismiss()
        queue.start(
            rawLyrics: trimmedLyrics,
            titleHint: trimmedTitle,
            artistHint: trimmedArtist,
            onComplete: onSuccess
        )
    }
}

private struct CandidateRow: View {
    let candidate: LookupCandidate
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title)
                        .font(.subheadline.weight(.semibold))
                    if !candidate.artist.isEmpty {
                        Text(candidate.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ConfidenceBadge(level: candidate.confidence)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(previewLines(candidate.devanagari))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if !candidate.notes.isEmpty {
                Text(candidate.notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func previewLines(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(3)
            .joined(separator: "\n")
        return lines
    }
}

private struct ConfidenceBadge: View {
    let level: String

    private var color: Color {
        switch level {
        case "high": return .green
        case "medium": return .orange
        case "low": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(level.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
