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
    @State private var spotifyQuery       = ""
    @State private var spotifyResults: [SpotifyTrack] = []
    @State private var isSpotifySearching = false
    @State private var spotifySearchTask: Task<Void, Never>?
    @State private var nowPlaying: SpotifyTrack?
    @State private var spotifyError: String?

    // Manual entry
    @State private var showManual   = false
    @State private var manualTitle  = ""
    @State private var manualArtist = ""

    // Lyrics
    @State private var isLyricsSearching  = false
    @State private var candidates: [LookupCandidate] = []
    @State private var lyricsError: String?
    @State private var selectedCandidateId: String?
    @State private var didLyricsSearch    = false
    @State private var isEditingLyrics    = false

    @State private var selectedImageUrl: String?
    @State private var generateError: String?

    private let maxChars = 30_000

    private var hasTitle: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canGenerate: Bool {
        hasTitle
            && !rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLyricsSearching
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.samajhBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hasTitle {
                        songHeroSection
                        lyricsSection
                    } else {
                        nowPlayingSection
                        searchSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, canGenerate ? 140 : 48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(SamajhMotion.standard, value: hasTitle)
            }

            if canGenerate {
                generateButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(SamajhMotion.standard, value: canGenerate)
        .navigationTitle(hasTitle ? "" : "Add Song")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if hasTitle {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(SamajhMotion.standard) { clearSong() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.caption.weight(.semibold))
                            Text("Change").font(.custom(SamajhFont.interRegular, size: 15))
                        }
                        .foregroundStyle(Color.samajhTextMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            guard spotify.isAuthorized else { return }
            nowPlaying = try? await spotify.currentlyPlaying()
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let track = nowPlaying {
            VStack(alignment: .leading, spacing: 10) {
                Text("Now Playing")
                    .font(.custom(SamajhFont.interMedium, size: 11))
                    .foregroundStyle(Color.samajhTextMuted)
                    .kerning(1.2)
                    .textCase(.uppercase)

                Button {
                    withAnimation(SamajhMotion.standard) { selectTrack(track) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.samajhGold.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .blur(radius: 14)
                            AlbumThumbnail(url: track.imageUrl, size: 52)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.name)
                                .font(.custom(SamajhFont.interSemiBold, size: 15))
                                .foregroundStyle(Color.samajhTextPrimary)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.custom(SamajhFont.interRegular, size: 13))
                                .foregroundStyle(Color.samajhTextSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.samajhGold)
                    }
                    .padding(14)
                    .background(Color.samajhSurfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: SamajhRadius.small))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 36)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(spotifyQuery.isEmpty ? Color.samajhTextMuted : Color.samajhGold)
                    .animation(SamajhMotion.fade, value: spotifyQuery.isEmpty)

                ZStack(alignment: .leading) {
                    if spotifyQuery.isEmpty && !showManual {
                        Text("What are you listening to?")
                            .font(.custom(SamajhFont.interRegular, size: 18))
                            .foregroundStyle(Color.samajhTextMuted)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $spotifyQuery)
                        .font(.custom(SamajhFont.interRegular, size: 18))
                        .foregroundStyle(Color.samajhTextPrimary)
                        .tint(Color.samajhGold)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: spotifyQuery) { _, q in
                            if !showManual { scheduleSearch(q) }
                        }
                        .opacity(showManual ? 0 : 1)
                }

                if isSpotifySearching {
                    ProgressView().tint(Color.samajhTextMuted).scaleEffect(0.85)
                } else if !spotifyQuery.isEmpty {
                    Button {
                        spotifyQuery = ""; spotifyResults = []; spotifyError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.samajhTextMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 20)

            Rectangle()
                .fill(Color.samajhSurfaceElevated)
                .frame(height: 1)

            // Manual entry morphs in below the field
            if showManual {
                manualEntrySection
            } else {
                // Live Spotify results
                if !spotifyResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(spotifyResults) { track in
                            spotifyRow(track: track)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }

                if let err = spotifyError {
                    Text(err)
                        .font(.custom(SamajhFont.interRegular, size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.top, 16)
                }

                // Fallback + Spotify connect nudge
                VStack(alignment: .leading, spacing: 16) {
                    if !spotifyQuery.isEmpty {
                        Button {
                            withAnimation(SamajhMotion.standard) {
                                showManual = true
                                spotifyQuery = ""
                                spotifyResults = []
                            }
                        } label: {
                            Text("Can't find it? Enter manually")
                                .font(.custom(SamajhFont.interRegular, size: 14))
                                .foregroundStyle(Color.samajhTextMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    if !spotify.isAuthorized {
                        Button { Task { await connectSpotify() } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note").font(.caption)
                                Text("Connect Spotify to see what's playing")
                                    .font(.custom(SamajhFont.interRegular, size: 13))
                            }
                            .foregroundStyle(Color.samajhGold.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 24)
            }
        }
    }

    // MARK: - Manual Entry

    @ViewBuilder
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Manual Entry")
                    .font(.custom(SamajhFont.interMedium, size: 11))
                    .foregroundStyle(Color.samajhTextMuted)
                    .kerning(1.2)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    withAnimation(SamajhMotion.standard) {
                        showManual = false; manualTitle = ""; manualArtist = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(.custom(SamajhFont.interRegular, size: 13))
                        .foregroundStyle(Color.samajhTextMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            darkTextField("Song title", text: $manualTitle)
                .textInputAutocapitalization(.words)

            Rectangle().fill(Color.samajhSurfaceElevated).frame(height: 1)

            darkTextField("Artist (optional)", text: $manualArtist)
                .textInputAutocapitalization(.words)

            Rectangle().fill(Color.samajhSurfaceElevated).frame(height: 1)

            Button {
                title = manualTitle
                artist = manualArtist
                showManual = false
                Task { await searchLyrics() }
            } label: {
                HStack(spacing: 8) {
                    if isLyricsSearching {
                        ProgressView().tint(Color.samajhGold).scaleEffect(0.85)
                        Text("Searching…")
                    } else {
                        Image(systemName: "magnifyingglass")
                        Text("Find lyrics")
                    }
                }
                .font(.custom(SamajhFont.interMedium, size: 15))
                .foregroundStyle(manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.samajhTextMuted : Color.samajhGold)
            }
            .buttonStyle(.plain)
            .disabled(manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLyricsSearching)
            .padding(.top, 20)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Song Hero

    @ViewBuilder
    private var songHeroSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.samajhGold.opacity(0.1))
                        .frame(width: 165, height: 165)
                        .blur(radius: 28)
                    AlbumThumbnail(url: selectedImageUrl, size: 140)
                }
                Spacer()
            }
            .padding(.bottom, 24)

            Text(title)
                .font(.custom(SamajhFont.interSemiBold, size: 22))
                .foregroundStyle(Color.samajhTextPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if !artist.isEmpty {
                Text(artist)
                    .font(.custom(SamajhFont.interRegular, size: 16))
                    .foregroundStyle(Color.samajhTextSecondary)
                    .padding(.top, 5)
            }
        }
        .padding(.bottom, 40)
        .transition(.opacity.combined(with: .scale(0.96, anchor: .top)))
    }

    // MARK: - Lyrics

    @ViewBuilder
    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.samajhSurfaceElevated)
                .frame(height: 1)
                .padding(.bottom, 28)

            if isLyricsSearching {
                shimmerLines
            } else if candidates.count > 1 {
                candidateCarousel
            } else if !rawLyrics.isEmpty {
                lyricsPreview
            } else if let err = lyricsError {
                VStack(alignment: .leading, spacing: 12) {
                    Text(err)
                        .font(.custom(SamajhFont.interRegular, size: 13))
                        .foregroundStyle(.red.opacity(0.7))
                    pasteLyricsArea
                }
            } else if didLyricsSearch {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No lyrics found")
                        .font(.custom(SamajhFont.interRegular, size: 14))
                        .foregroundStyle(Color.samajhTextMuted)
                    pasteLyricsArea
                }
            }
        }
    }

    // Shimmer placeholder while fetching
    private var shimmerLines: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach([220, 170, 210, 150] as [CGFloat], id: \.self) { w in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.samajhSurfaceElevated)
                    .frame(width: w, height: 24)
            }
        }
    }

    // Native script preview with fade + optional edit
    private var lyricsPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            let lines = rawLyrics
                .split(separator: "\n", omittingEmptySubsequences: true)
                .prefix(6)
                .joined(separator: "\n")

            Text(lines)
                .font(.custom(SamajhFont.notoDevanagari, size: 22))
                .foregroundStyle(Color.samajhTextSecondary)
                .lineSpacing(6)
                .mask {
                    LinearGradient(
                        colors: [.black, .black, .black.opacity(0.2), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                }

            if isEditingLyrics {
                TextEditor(text: $rawLyrics)
                    .font(.custom(SamajhFont.notoDevanagari, size: 18))
                    .foregroundStyle(Color.samajhTextPrimary)
                    .tint(Color.samajhGold)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            Button {
                withAnimation(SamajhMotion.standard) { isEditingLyrics.toggle() }
            } label: {
                Text(isEditingLyrics ? "Done editing" : "Edit lyrics")
                    .font(.custom(SamajhFont.interRegular, size: 13))
                    .foregroundStyle(Color.samajhTextMuted)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
    }

    // Swipeable candidate cards
    private var candidateCarousel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiple versions found")
                .font(.custom(SamajhFont.interMedium, size: 11))
                .foregroundStyle(Color.samajhTextMuted)
                .kerning(1.2)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(candidates) { candidate in
                        let isSelected = candidate.id == selectedCandidateId
                        Button {
                            withAnimation(SamajhMotion.fade) {
                                selectedCandidateId = candidate.id
                                rawLyrics = candidate.devanagari
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.title)
                                            .font(.custom(SamajhFont.interSemiBold, size: 13))
                                            .foregroundStyle(Color.samajhTextPrimary)
                                            .lineLimit(1)
                                        if !candidate.artist.isEmpty {
                                            Text(candidate.artist)
                                                .font(.custom(SamajhFont.interRegular, size: 12))
                                                .foregroundStyle(Color.samajhTextSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.samajhGold)
                                    }
                                }

                                Text(previewLines(candidate.devanagari))
                                    .font(.custom(SamajhFont.notoDevanagari, size: 16))
                                    .foregroundStyle(Color.samajhTextSecondary)
                                    .lineLimit(3)
                                    .lineSpacing(4)

                                ConfidenceDot(level: candidate.confidence)
                            }
                            .padding(16)
                            .frame(width: 260, alignment: .leading)
                            .background(Color.samajhSurfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: SamajhRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: SamajhRadius.small)
                                    .stroke(isSelected ? Color.samajhGold.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 24)
            }
            .padding(.horizontal, -24) // bleed to edges
        }
    }

    // Editable paste area when no lyrics found
    private var pasteLyricsArea: some View {
        ZStack(alignment: .topLeading) {
            if rawLyrics.isEmpty {
                Text("Paste lyrics here…")
                    .font(.custom(SamajhFont.notoDevanagari, size: 20))
                    .foregroundStyle(Color.samajhTextMuted.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $rawLyrics)
                .font(.custom(SamajhFont.notoDevanagari, size: 20))
                .foregroundStyle(Color.samajhTextPrimary)
                .tint(Color.samajhGold)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
        }
        .padding(16)
        .background(Color.samajhSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: SamajhRadius.small))
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.samajhBackground.opacity(0), Color.samajhBackground],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 48)
            .allowsHitTesting(false)

            Button { Task { await submit() } } label: {
                HStack(spacing: 8) {
                    Text("Generate lesson")
                        .font(.custom(SamajhFont.interSemiBold, size: 17))
                    Image(systemName: "arrow.right")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(Color.samajhBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.samajhGold)
                .clipShape(RoundedRectangle(cornerRadius: SamajhRadius.button))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .background(Color.samajhBackground)
        }
    }

    // MARK: - Helpers

    private func spotifyRow(track: SpotifyTrack) -> some View {
        Button {
            withAnimation(SamajhMotion.standard) { selectTrack(track) }
        } label: {
            HStack(spacing: 12) {
                AlbumThumbnail(url: track.imageUrl, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name)
                        .font(.custom(SamajhFont.interRegular, size: 15))
                        .foregroundStyle(Color.samajhTextPrimary)
                        .lineLimit(1)
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.custom(SamajhFont.interRegular, size: 13))
                            .foregroundStyle(Color.samajhTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func darkTextField(_ placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.custom(SamajhFont.interRegular, size: 17))
                    .foregroundStyle(Color.samajhTextMuted)
                    .allowsHitTesting(false)
            }
            TextField("", text: text)
                .font(.custom(SamajhFont.interRegular, size: 17))
                .foregroundStyle(Color.samajhTextPrimary)
                .tint(Color.samajhGold)
        }
        .padding(.vertical, 16)
    }

    private func previewLines(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: true).prefix(3).joined(separator: "\n")
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

    private func clearSong() {
        title = ""; artist = ""; selectedImageUrl = nil
        candidates = []; selectedCandidateId = nil
        rawLyrics = ""; lyricsError = nil
        didLyricsSearch = false; isEditingLyrics = false
        generateError = nil
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
        lyricsError = nil; candidates = []
        selectedCandidateId = nil; isLyricsSearching = true
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
        generateError = nil; isEditingLyrics = false
        manualTitle = ""; manualArtist = ""
    }

    private func submit() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = rawLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { generateError = "Title is required"; return }
        guard !l.isEmpty else { generateError = "Please add lyrics"; return }
        let img = selectedImageUrl
        queue.start(rawLyrics: l, titleHint: t, artistHint: a, imageUrl: img, onComplete: { _ in })
        clearForm()
        onGenerate()
    }
}

// MARK: - Confidence dot

private struct ConfidenceDot: View {
    let level: String
    private var color: Color {
        switch level { case "high": .green; case "medium": .orange; case "low": .red; default: .gray }
    }
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(level.capitalized)
                .font(.custom(SamajhFont.interRegular, size: 11))
                .foregroundStyle(color.opacity(0.8))
        }
    }
}
