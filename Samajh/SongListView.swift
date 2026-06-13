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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("samajh")
                    .font(.custom(SamajhFont.cormorantMedium, size: 28))
                    .foregroundStyle(Color.samajhGold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingProfile = true } label: {
                    UserAvatarView()
                }
            }
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

struct ProfileSheet: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    private var displayName: String? {
        let first = Clerk.shared.user?.firstName ?? ""
        let last = Clerk.shared.user?.lastName ?? ""
        let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? nil : full
    }

    private var email: String? {
        Clerk.shared.user?.emailAddresses.first?.emailAddress
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let urlStr = Clerk.shared.user?.imageUrl, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(Color.samajhTextSecondary)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.samajhTextSecondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                if let name = displayName {
                    Section("Name") {
                        Text(name)
                            .foregroundStyle(.primary)
                    }
                }

                if let email = email {
                    Section("Email") {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        auth.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct UserAvatarView: View {
    private let gold = Color.samajhGold

    private var initial: String {
        if let first = Clerk.shared.user?.firstName, let ch = first.first { return String(ch) }
        if let email = Clerk.shared.user?.emailAddresses.first?.emailAddress, let ch = email.first { return String(ch).uppercased() }
        return "?"
    }

    var body: some View {
        if let urlStr = Clerk.shared.user?.imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(gold.opacity(0.12))
            Text(initial)
                .font(.custom(SamajhFont.cormorantMedium, size: 15))
                .foregroundStyle(gold)
        }
        .frame(width: 28, height: 28)
        .overlay(Circle().stroke(gold.opacity(0.4), lineWidth: 1))
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
