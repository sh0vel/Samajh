import SwiftUI

struct FavoriteFlightOverlay: View {
    let flight: FavoriteFlight
    let onComplete: () -> Void

    @State private var cardPosition: CGPoint
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var heartScale: CGFloat = 0.6

    private let screenSize: CGSize = {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .screen.bounds.size ?? UIScreen.main.bounds.size
    }()

    // Favorites is the 3rd of 3 tabs — center x ≈ 5/6 screen width.
    // Tab icon sits above the home indicator; y ≈ screenHeight - 28.
    private var targetPoint: CGPoint {
        CGPoint(x: screenSize.width * 5.0 / 6.0, y: screenSize.height - 28)
    }

    init(flight: FavoriteFlight, onComplete: @escaping () -> Void) {
        self.flight = flight
        self.onComplete = onComplete
        let src = flight.sourceFrame
        _cardPosition = State(initialValue: CGPoint(x: src.midX, y: src.midY))
    }

    var body: some View {
        ZStack {
            // Flying lyric card
            Text(flight.text)
                .font(.custom(SamajhFont.interRegular, size: 14))
                .foregroundStyle(Color.samajhGold)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.samajhSurfaceCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.samajhGold.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(color: Color.samajhGold.opacity(0.14), radius: 14, x: 0, y: 6)
                )
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
                .position(cardPosition)
                .allowsHitTesting(false)

            // Heart glow at Favorites tab position — appears as card arrives
            ZStack {
                Circle()
                    .fill(Color.samajhGold.opacity(0.25))
                    .frame(width: 58, height: 58)
                    .blur(radius: 16)

                Image(systemName: "heart.fill")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.samajhGold)
                    .scaleEffect(heartScale)
            }
            .opacity(glowOpacity)
            .position(targetPoint)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear { runSequence() }
    }

    private func runSequence() {
        // Phase 1 — card materialises at source row (0 ms)
        withAnimation(.easeOut(duration: 0.13)) {
            cardOpacity = 0.90
        }

        // Phase 2 — smooth drift toward Favorites tab (100 ms start, 520 ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeInOut(duration: 0.52)) {
                cardPosition = targetPoint
                cardScale    = 0.82
                cardOpacity  = 0.68
            }
        }

        // Phase 3 — card slips away; heart blooms (560 ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            withAnimation(.easeOut(duration: 0.13)) {
                cardOpacity = 0
                glowOpacity = 1.0
                heartScale  = 1.12
            }
        }

        // Phase 4 — heart settles from pulse (700 ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            withAnimation(.easeOut(duration: 0.14)) {
                heartScale = 1.0
            }
        }

        // Phase 5 — glow fades to nothing (760 ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.76) {
            withAnimation(.easeOut(duration: 0.34)) {
                glowOpacity = 0
            }
        }

        // Done — clear coordinator (~1.1 s total)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) {
            onComplete()
        }
    }
}
