import SwiftUI
import AuthenticationServices

struct SplashView: View {
    let authManager: AuthManager
    let isReturningUser: Bool
    let onComplete: () -> Void

    @State private var glowOpacity: Double = 0
    @State private var glowPulse: Double = 0
    @State private var scriptsOpacity: Double = 0
    @State private var scriptBlur: CGFloat = 10
    @State private var spread: CGFloat = 1
    @State private var samajhOpacity: Double = 0
    @State private var samajhScale: CGFloat = 0.6
    @State private var showSignIn: Bool = false
    @State private var animationCompleted: Bool = false

    private let spreadOffset: CGFloat = 140
    private let gold = Color(red: 0.84, green: 0.63, blue: 0.37)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [gold.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            RadialGradient(
                colors: [gold.opacity(0.28), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(glowPulse)

            VStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .center) {
                    if !isReturningUser {
                        Text("समझ")
                            .font(.custom(SamajhFont.notoDevanagari, size: 42))
                            .foregroundStyle(gold.opacity(0.72))
                            .offset(x: -spreadOffset * spread, y: 6)
                            .scaleEffect(0.1 + 0.9 * spread)
                            .opacity(Double(spread) * scriptsOpacity)
                            .blur(radius: scriptBlur)

                        Text("سمجھ")
                            .font(.custom("GeezaPro", size: 44))
                            .foregroundStyle(gold.opacity(0.72))
                            .offset(y: -8)
                            .scaleEffect(0.1 + 0.9 * spread)
                            .opacity(Double(spread) * scriptsOpacity)
                            .blur(radius: scriptBlur)

                        Text("সমঝ")
                            .font(.custom(SamajhFont.notoBengali, size: 42))
                            .foregroundStyle(gold.opacity(0.72))
                            .offset(x: spreadOffset * spread, y: 3)
                            .scaleEffect(0.1 + 0.9 * spread)
                            .opacity(Double(spread) * scriptsOpacity)
                            .blur(radius: scriptBlur)
                    }

                    Text("samajh")
                        .font(.custom(SamajhFont.cormorantMedium, size: 62))
                        .foregroundStyle(gold)
                        .opacity(samajhOpacity)
                        .scaleEffect(samajhScale)
                }
                .frame(maxWidth: .infinity, minHeight: 90)

                if showSignIn {
                    signInSection
                        .padding(.top, 52)
                        .transition(.opacity)
                }

                Spacer()

                if !isReturningUser {
                    PulsingDots()
                        .padding(.bottom, 110)
                        .opacity(showSignIn ? 0 : glowOpacity)
                }
            }
        }
        .onAppear { isReturningUser ? beginShortSequence() : beginFullSequence() }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            guard animationCompleted, isSignedIn else { return }
            onComplete()
        }
    }

    @ViewBuilder
    private var signInSection: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
                request.nonce = UUID().uuidString
            } onCompletion: { result in
                Task { await authManager.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(width: 280, height: 50)
            .clipShape(Capsule())

            Button {
                authManager.signInWithGoogle()
            } label: {
                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold))
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .medium))
                }
                .frame(width: 280, height: 50)
                .background(gold)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 4)
            }

            if authManager.isLoading {
                ProgressView()
                    .tint(gold)
                    .padding(.top, 4)
            }
        }
    }

    // Returning signed-in users: quick logo flash then go
    private func beginShortSequence() {
        withAnimation(.easeOut(duration: 0.4)) {
            samajhOpacity = 1
            samajhScale = 1.0
            glowOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            animationCompleted = true
            onComplete()
        }
    }

    // New/signed-out users: full cinematic sequence
    private func beginFullSequence() {
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
                    animationCompleted = true
                    if authManager.isSignedIn {
                        onComplete()
                    } else {
                        withAnimation(.easeIn(duration: 0.5)) { showSignIn = true }
                    }
                }
            }
        }
    }
}

private struct PulsingDots: View {
    private let gold = Color(red: 0.84, green: 0.63, blue: 0.37)
    @State private var phase: Int = 0

    var body: some View {
        ZStack {
            // soft glow behind the dots
            Ellipse()
                .fill(gold.opacity(0.12))
                .frame(width: 90, height: 28)
                .blur(radius: 12)

            HStack(spacing: 14) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(gold)
                        .frame(width: 9, height: 9)
                        .opacity(phase == i ? 1.0 : 0.22)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .shadow(color: gold.opacity(phase == i ? 0.7 : 0), radius: 6)
                        .animation(.easeInOut(duration: 0.4), value: phase)
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
