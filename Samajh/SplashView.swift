import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    @State private var glowOpacity: Double = 0
    @State private var glowPulse: Double = 0
    @State private var scriptsOpacity: Double = 0
    @State private var scriptBlur: CGFloat = 10
    @State private var spread: CGFloat = 1
    @State private var samajhOpacity: Double = 0
    @State private var samajhScale: CGFloat = 0.6

    private let spreadOffset: CGFloat = 140

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 0.84, green: 0.63, blue: 0.37).opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            RadialGradient(
                colors: [Color(red: 0.84, green: 0.63, blue: 0.37).opacity(0.28), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(glowPulse)

            VStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .center) {
                    Text("समझ")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(red: 0.84, green: 0.63, blue: 0.37).opacity(0.72))
                        .offset(x: -spreadOffset * spread, y: 6)
                        .scaleEffect(0.1 + 0.9 * spread)
                        .opacity(Double(spread) * scriptsOpacity)
                        .blur(radius: scriptBlur)

                    Text("سمجھ")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(red: 0.84, green: 0.63, blue: 0.37).opacity(0.72))
                        .environment(\.layoutDirection, .rightToLeft)
                        .offset(y: -8)
                        .scaleEffect(0.1 + 0.9 * spread)
                        .opacity(Double(spread) * scriptsOpacity)
                        .blur(radius: scriptBlur)

                    Text("সমঝ")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(red: 0.84, green: 0.63, blue: 0.37).opacity(0.72))
                        .offset(x: spreadOffset * spread, y: 3)
                        .scaleEffect(0.1 + 0.9 * spread)
                        .opacity(Double(spread) * scriptsOpacity)
                        .blur(radius: scriptBlur)

                    Text("samajh")
                        .font(.system(size: 58, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.84, green: 0.63, blue: 0.37))
                        .opacity(samajhOpacity)
                        .scaleEffect(samajhScale)
                }
                .frame(maxWidth: .infinity, minHeight: 90)

                Spacer()

                PulsingDots()
                    .padding(.bottom, 64)
                    .opacity(glowOpacity)
            }
        }
        .onAppear { beginSequence() }
    }

    private func beginSequence() {
        withAnimation(.easeOut(duration: 0.65)) {
            glowOpacity = 1
            scriptsOpacity = 1
            scriptBlur = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeInOut(duration: 0.5)) { spread = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                    samajhOpacity = 1
                    samajhScale = 1.0
                }
                withAnimation(.easeOut(duration: 0.25)) { glowPulse = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 1.0)) { glowPulse = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    onComplete()
                }
            }
        }
    }
}

private struct PulsingDots: View {
    private let gold = Color(red: 0.84, green: 0.63, blue: 0.37)
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(gold)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 0.9 : 0.2)
                    .scaleEffect(phase == i ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: phase)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
