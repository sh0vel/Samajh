import SwiftUI

@main
struct SamajhApp: App {
    @StateObject private var generationQueue = GenerationQueue()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var spotify = SpotifyManager()
    @StateObject private var songListVM = SongListViewModel()
    @StateObject private var flightCoordinator = FavoriteFlightCoordinator()
    @State private var selectedTab = 0
    @State private var showSplash = true
    @State private var splashAnimationDone = false

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

                NavigationStack {
                    AddLyricsView(onGenerate: { selectedTab = 0 })
                }
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(1)

                NavigationStack {
                    FavoritesView()
                        .navigationDestination(for: SongMetadata.self) { song in
                            LyricsView(songId: song.songId, imageUrl: song.imageUrl)
                        }
                        .navigationDestination(for: SongTarget.self) { target in
                            LyricsView(songId: target.songId, imageUrl: target.imageUrl, targetLineId: target.lineId)
                        }
                }
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(2)
            }
            .environmentObject(generationQueue)
            .environmentObject(favorites)
            .environmentObject(spotify)
            .environmentObject(songListVM)
            .environmentObject(flightCoordinator)
            .task { await songListVM.load() }
            .overlay {
                if let flight = flightCoordinator.activeFlight {
                    FavoriteFlightOverlay(flight: flight) {
                        flightCoordinator.finish()
                    }
                }
            }
            .overlay {
                if showSplash {
                    SplashView { splashAnimationDone = true }
                        .ignoresSafeArea()
                }
            }
            .onChange(of: splashAnimationDone) { _, done in
                if done && !songListVM.isLoading { withAnimation { showSplash = false } }
            }
            .onChange(of: songListVM.isLoading) { _, loading in
                if !loading && splashAnimationDone { withAnimation { showSplash = false } }
            }
        }
    }
}
