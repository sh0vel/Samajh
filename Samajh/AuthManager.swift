import Foundation
import ClerkSDK
import AuthenticationServices

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool = false
    @Published var sessionToken: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var userId: String? { Clerk.shared.user?.id }

    private init() {
        Clerk.configure(publishableKey: "pk_test_d29ya2FibGUtamFja2FsLTQ3LmNsZXJrLmFjY291bnRzLmRldiQ")
        Task { await syncAuthState() }
    }

    func syncAuthState() async {
        isSignedIn = Clerk.shared.session != nil
        if isSignedIn {
            sessionToken = try? await Clerk.shared.session?.getToken()
        } else {
            sessionToken = nil
        }
    }

    // Called from SignInWithAppleButton's onCompletion callback
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
            return
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign In: missing identity token"
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                try await Clerk.shared.auth.signInWithIdToken(idToken, provider: .apple)
                await syncAuthState()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signInWithGoogle() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await Clerk.shared.auth.signInWithOAuth(provider: .google)
                await syncAuthState()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            try? await Clerk.shared.auth.signOut()
            isSignedIn = false
            sessionToken = nil
        }
    }
}
