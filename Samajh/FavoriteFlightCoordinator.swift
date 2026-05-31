import SwiftUI

struct FavoriteFlight: Identifiable {
    let id = UUID()
    let text: String
    let sourceFrame: CGRect
}

@MainActor
final class FavoriteFlightCoordinator: ObservableObject {
    @Published var activeFlight: FavoriteFlight?

    func fly(text: String, from frame: CGRect) {
        guard activeFlight == nil else { return }
        activeFlight = FavoriteFlight(text: text, sourceFrame: frame)
    }

    func finish() {
        activeFlight = nil
    }
}
