import Foundation

struct FavoriteLine: Codable, Identifiable, Hashable {
    let lineId: String
    let songId: String
    let songTitle: String
    let target: String
    let roman: String
    let natural: String?

    var id: String { lineId }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteLines: [FavoriteLine] = []

    func load() async {
        do {
            favoriteLines = try await APIClient.shared.getFavorites()
        } catch {
            print("[FavoritesStore] load failed: \(error)")
        }
    }

    func toggle(line: FavoriteLine) {
        if let idx = favoriteLines.firstIndex(where: { $0.lineId == line.lineId && $0.songId == line.songId }) {
            favoriteLines.remove(at: idx)
            Task { try? await APIClient.shared.removeFavorite(lineId: line.lineId) }
        } else {
            favoriteLines.append(line)
            Task { try? await APIClient.shared.addFavorite(line) }
        }
    }

    func isFavorite(lineId: String, songId: String) -> Bool {
        favoriteLines.contains(where: { $0.lineId == lineId && $0.songId == songId })
    }
}
