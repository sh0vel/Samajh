import SwiftUI

@main
struct SamajhApp: App {
    @StateObject private var generationQueue = GenerationQueue()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var spotify = SpotifyManager()
    @StateObject private var songListVM = SongListViewModel()
    @StateObject private var flightCoordinator = FavoriteFlightCoordinator()
    @StateObject private var auth: AuthManager
    @State private var selectedTab = 0
    @State private var showSplash = true

    init() {
        _auth = StateObject(wrappedValue: AuthManager.shared)
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
            .environmentObject(auth)
            .task(id: auth.isSignedIn) {
                guard auth.isSignedIn else { return }
                await songListVM.load()
                await favorites.load()
            }
            .onOpenURL { url in spotify.handleURL(url) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                spotify.appDidBecomeActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                spotify.appDidEnterBackground()
            }
            .overlay {
                if let flight = flightCoordinator.activeFlight {
                    FavoriteFlightOverlay(flight: flight) {
                        flightCoordinator.finish()
                    }
                }
            }
            .overlay {
                if showSplash {
                    SplashView(authManager: auth, isReturningUser: auth.isSignedIn) {
                        withAnimation { showSplash = false }
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
}
