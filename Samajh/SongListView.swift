import SwiftUI

@MainActor
final class SongListViewModel: ObservableObject {
    @Published var songs: [SongMetadata] = []
    @Published var isLoading = false
    @Published var error: String?

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

struct SongListView: View {
    @Binding var path: NavigationPath
    @StateObject private var vm = SongListViewModel()
    @State private var showingAdd = false

    var body: some View {
        Group {
            if vm.isLoading && vm.songs.isEmpty {
                ProgressView("Loading songs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error, vm.songs.isEmpty {
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
            } else if vm.songs.isEmpty {
                VStack(spacing: 8) {
                    Text("No songs yet")
                        .font(.headline)
                    Text("Tap + to add your first lesson")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.songs) { song in
                    NavigationLink(value: song.songId) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.headline)
                            HStack {
                                if let artist = song.artist, !artist.isEmpty {
                                    Text(artist)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(DateFormatting.relative(from: song.updatedAt))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .refreshable {
                    await vm.load()
                }
            }
        }
        .navigationTitle("Samajh")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add lyrics")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddLyricsView { newSongId in
                showingAdd = false
                Task {
                    await vm.load()
                    path.append(newSongId)
                }
            }
        }
        .task {
            if vm.songs.isEmpty {
                await vm.load()
            }
        }
    }
}
