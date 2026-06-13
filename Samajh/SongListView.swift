import SwiftUI
import ClerkKit

@MainActor
final class SongListViewModel: ObservableObject {
    @Published var songs: [SongMetadata] = []
    @Published var isLoading = false
    @Published var error: String?

    func remove(songId: String) {
        withAnimation {
            songs.removeAll { $0.songId == songId }
        }
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            songs = try await APIClient.shared.listSongs()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private let generationPhrases = [
    "Breaking it down…",
    "Finding the words…",
    "Learning the song…",
    "Building your lesson…",
    "Almost ready…",
]

struct SongListView: View {
    @EnvironmentObject private var vm: SongListViewModel
    @EnvironmentObject private var queue: GenerationQueue
    @EnvironmentObject private var auth: AuthManager
    @State private var phraseIndex = 0
    @State private var flashedSongId: String?
    @State private var flashOpacity: Double = 0
    @State private var showingProfile = false

    var body: some View {
        Group {
            if let error = vm.error, vm.songs.isEmpty {
                VStack(spacing: 12) {
                    Text("Couldn't load songs")
                        .font(.headline)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.isLoading && vm.songs.isEmpty {
                List {
                    ForEach(0..<6, id: \.self) { _ in
                        SongRowSkeleton()
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            } else if vm.songs.isEmpty && !queue.isGenerating {
                VStack(spacing: 20) {
                    Text("samajh")
                        .font(.custom(SamajhFont.cormorantMedium, size: 52))
                        .foregroundStyle(Color.samajhGold)
                    Text("Every song holds a lesson.")
                        .font(.custom(SamajhFont.interRegular, size: 17))
                        .foregroundStyle(Color.samajhTextSecondary)
                    Text("Tap + to start your first lesson.")
                        .font(.custom(SamajhFont.interRegular, size: 14))
                        .foregroundStyle(Color.samajhTextMuted)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                List {
                    ForEach(queue.pendingJobs) { job in
                        HStack(spacing: 12) {
                            AlbumThumbnail(url: job.imageUrl, size: 44)
                                .overlay(alignment: .bottomTrailing) {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.65)
                                        .padding(3)
                                        .background(Circle().fill(Color.accentColor))
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                                Text(generationPhrases[phraseIndex])
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor.opacity(0.7))
                                    .contentTransition(.opacity)
                                    .animation(.easeInOut(duration: 0.5), value: phraseIndex)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if let err = queue.errorMessage {
                        Text("Generation failed: \(err)")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    ForEach(vm.songs) { song in
                        NavigationLink(value: song) {
                            HStack(spacing: 12) {
                                AlbumThumbnail(url: song.imageUrl, size: 48)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(song.title)
                                        .font(.custom(SamajhFont.interSemiBold, size: 16))
                                        .foregroundStyle(Color.samajhTextPrimary)
                                    HStack {
                                        if let artist = song.artist, !artist.isEmpty {
                                            Text(artist)
                                                .font(.custom(SamajhFont.interRegular, size: 14))
                                                .foregroundStyle(Color.samajhTextSecondary)
                                        }
                                        Spacer()
                                        Text(DateFormatting.relative(from: song.createdAt))
                                            .font(.custom(SamajhFont.interRegular, size: 12))
                                            .foregroundStyle(Color.samajhTextMuted)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(
                            Color.accentColor
                                .opacity(song.songId == flashedSongId ? flashOpacity * 0.18 : 0)
                        )
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await vm.load()
                }
                .onChange(of: queue.pendingJobs.count) { old, new in
                    if new > old, let first = queue.pendingJobs.first {
                        withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                    }
                }
                } // ScrollViewReader
            }
        }
        .navigationTitle("Samajh")
        .overlay(alignment: .topTrailing) {
            Button { showingProfile = true } label: {
                UserAvatarBadge()
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheet(auth: auth)
        }
        .task(id: auth.isSignedIn) {
            guard auth.isSignedIn else { return }
            await vm.load()
        }
        // Rotate status phrases while any job is in progress
        .task(id: queue.pendingJobs.isEmpty) {
            guard !queue.pendingJobs.isEmpty else { return }
            phraseIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                phraseIndex = (phraseIndex + 1) % generationPhrases.count
            }
        }
        // Reload + flash the new row when generation finishes
        .onChange(of: queue.isGenerating) { _, nowGenerating in
            if !nowGenerating {
                let previousIds = Set(vm.songs.map { $0.songId })
                Task {
                    await vm.load()
                    if let newSong = vm.songs.first(where: { !previousIds.contains($0.songId) }) {
                        await flashRow(for: newSong.songId)
                    }
                }
            }
        }
    }

    private func flashRow(for songId: String) async {
        flashedSongId = songId
        withAnimation(.easeIn(duration: 0.25)) { flashOpacity = 1 }
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        withAnimation(.easeOut(duration: 1.1)) { flashOpacity = 0 }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        flashedSongId = nil
    }
}

private struct UserAvatarBadge: View {
    private let gold = Color(red: 0.83, green: 0.63, blue: 0.35)

    private var initials: String {
        let f = Clerk.shared.user?.firstName?.first.map(String.init) ?? ""
        let l = Clerk.shared.user?.lastName?.first.map(String.init) ?? ""
        let combined = f + l
        return combined.isEmpty ? "·" : combined
    }

    var body: some View {
        ZStack {
            Circle().stroke(gold.opacity(0.45), lineWidth: 1)
            Text(initials)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(gold)
        }
        .frame(width: 30, height: 30)
    }
}

struct ProfileSheet: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var displayName: String? {
        let parts = [Clerk.shared.user?.firstName, Clerk.shared.user?.lastName]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var email: String? {
        Clerk.shared.user?.emailAddresses.first?.emailAddress
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.samajhBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let name = displayName {
                            Text(name)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.samajhTextPrimary)
                        }
                        if let email = email {
                            Text(email)
                                .font(.custom(SamajhFont.interRegular, size: 15))
                                .foregroundStyle(Color.samajhTextMuted)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 36)

                    Spacer()

                    VStack(spacing: 0) {
                        Divider().overlay(Color.samajhSurfaceElevated)

                        Button {
                            dismiss()
                            auth.signOut()
                        } label: {
                            Text("Sign Out")
                                .font(.custom(SamajhFont.interMedium, size: 16))
                                .foregroundStyle(Color.samajhGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 18)
                        }

                        Divider().overlay(Color.samajhSurfaceElevated)

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Account")
                                .font(.custom(SamajhFont.interMedium, size: 16))
                                .foregroundStyle(Color(red: 0.788, green: 0.420, blue: 0.420))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 18)
                        }
                        .disabled(isDeleting)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.custom(SamajhFont.interMedium, size: 16))
                        .foregroundStyle(Color.samajhGold)
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeleting = true
                        await auth.deleteAccount()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all your songs. This cannot be undone.")
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.samajhBackground)
    }
}

private struct SongRowSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.samajhTextMuted.opacity(0.18))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.samajhTextMuted.opacity(0.18))
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.samajhTextMuted.opacity(0.12))
                    .frame(width: 100, height: 11)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .opacity(shimmer ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}
