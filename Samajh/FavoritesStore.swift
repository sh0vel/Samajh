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

final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteLines: [FavoriteLine] = []
    private static let key = "favoriteLines"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([FavoriteLine].self, from: data) {
            favoriteLines = saved
        }
    }

    func toggle(line: FavoriteLine) {
        if let idx = favoriteLines.firstIndex(where: { $0.lineId == line.lineId }) {
            favoriteLines.remove(at: idx)
        } else {
            favoriteLines.append(line)
        }
        persist()
    }

    func isFavorite(lineId: String) -> Bool {
        favoriteLines.contains(where: { $0.lineId == lineId })
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(favoriteLines) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
