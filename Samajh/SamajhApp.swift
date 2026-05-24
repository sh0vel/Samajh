import SwiftUI

@main
struct SamajhApp: App {
    @StateObject private var generationQueue = GenerationQueue()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    SongListView()
                        .navigationDestination(for: String.self) { songId in
                            LyricsView(songId: songId)
                        }
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }

                NavigationStack {
                    FavoritesView()
                        .navigationDestination(for: String.self) { songId in
                            LyricsView(songId: songId)
                        }
                }
                .tabItem { Label("Favorites", systemImage: "heart") }
            }
            .environmentObject(generationQueue)
            .environmentObject(favorites)
        }
    }
}
