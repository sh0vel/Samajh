import SwiftUI

struct AlbumThumbnail: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.15)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.tertiary)
            )
    }
}
