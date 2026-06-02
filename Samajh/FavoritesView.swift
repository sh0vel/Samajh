import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore

    private var grouped: [(songTitle: String, songId: String, lines: [FavoriteLine])] {
        var seen: [String: Int] = [:]
        var result: [(songTitle: String, songId: String, lines: [FavoriteLine])] = []
        for line in favorites.favoriteLines {
            if let idx = seen[line.songId] {
                result[idx].lines.append(line)
            } else {
                seen[line.songId] = result.count
                result.append((line.songTitle, line.songId, [line]))
            }
        }
        return result
    }

    var body: some View {
        Group {
            if favorites.favoriteLines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No favorites yet")
                        .font(.title3.weight(.medium))
                    Text("Long-press a line in any song to save it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.songId) { group in
                        Section(group.songTitle) {
                            ForEach(group.lines) { line in
                                NavigationLink(value: SongTarget(songId: line.songId, lineId: line.lineId)) {
                                    FavoriteLineLabel(line: line)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        favorites.toggle(line: line)
                                    } label: {
                                        Label("Remove from Favorites", systemImage: "heart.slash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Favorites")
    }
}

private struct FavoriteLineLabel: View {
    let line: FavoriteLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(line.roman)
                .font(.body.weight(.medium))
            if let nat = line.natural, !nat.isEmpty {
                Text(nat)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
