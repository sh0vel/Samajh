import SwiftUI

@main
struct SamajhApp: App {
    @State private var path = NavigationPath()
    @StateObject private var generationQueue = GenerationQueue()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                SongListView(path: $path)
                    .navigationDestination(for: String.self) { songId in
                        LyricsView(songId: songId)
                    }
            }
            .environmentObject(generationQueue)
        }
    }
}
