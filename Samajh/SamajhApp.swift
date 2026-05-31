import SwiftUI

@main
struct SamajhApp: App {
    @StateObject private var generationQueue = GenerationQueue()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var spotify = SpotifyManager()
    @State private var selectedTab = 0
    @State private var lastContentTab = 0
    @State private var showingAdd = false
    @State private var showSplash = true

    init() {
        Task.detached(priority: .background) { SamajhFonts.register() }
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    SongListView()
                        .navigationDestination(for: SongMetadata.self) { song in
                            LyricsView(songId: song.songId, imageUrl: song.imageUrl)
                        }
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }
                .tag(0)

                Color.clear
                    .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                    .tag(1)

                NavigationStack {
                    FavoritesView()
                        .navigationDestination(for: SongMetadata.self) { song in
                            LyricsView(songId: song.songId, imageUrl: song.imageUrl)
                        }
                        .navigationDestination(for: String.self) { songId in
                            LyricsView(songId: songId)
                        }
                }
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(2)
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 1 {
                    showingAdd = true
                    selectedTab = lastContentTab
                } else {
                    lastContentTab = newTab
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLyricsView { _ in }
            }
            .environmentObject(generationQueue)
            .environmentObject(favorites)
            .environmentObject(spotify)
            .overlay {
                if showSplash {
                    SplashView { withAnimation { showSplash = false } }
                        .ignoresSafeArea()
                }
            }
        }
    }
}
