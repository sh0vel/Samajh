import Foundation
import UIKit
import AuthenticationServices
import Security
import CryptoKit
import SpotifyiOS

// MARK: - Public model

struct SpotifyTrack: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let artist: String
    let imageUrl: String?
}

// MARK: - Error

enum SpotifyError: LocalizedError {
    case notAuthorized, cancelled, noCode, notInstalled, noResults

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Not connected to Spotify"
        case .cancelled:     return "Spotify login cancelled"
        case .noCode:        return "No authorization code received"
        case .notInstalled:  return "Spotify is not installed"
        case .noResults:     return "Song not found on Spotify"
        }
    }
}

// MARK: - PKCE

private enum PKCE {
    static func generateVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Keychain

private enum KV {
    static func set(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        if SecItemUpdate(q as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            var add = q; add[kSecValueData] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                   kSecReturnData: kCFBooleanTrue!, kSecMatchLimit: kSecMatchLimitOne]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
    }
}

// MARK: - Presentation anchor

private final class PresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        return scene?.windows.first(where: { $0.isKeyWindow })
            ?? scene?.windows.first
            ?? UIWindow()
    }
}

// MARK: - SpotifyManager

@MainActor
final class SpotifyManager: NSObject, ObservableObject {

    private let clientId    = "55c2275c63634074aa13b4d40e359e6f"
    private let redirectURI = "samajh://spotify-callback"

    // Web API auth state
    @Published var isAuthorized    = false
    @Published var isConnected     = false   // App Remote connection
    @Published var isPlaying       = false
    @Published var isBusy          = false   // searching / connecting
    @Published var nowPlayingTitle: String?  // title of the song currently playing

    private var accessToken:  String?
    private var refreshToken: String?
    private var expiresAt:    Date?

    private var codeVerifier     = ""
    private var isAuthenticating = false
    private var activeSession:   ASWebAuthenticationSession?
    private var pendingPlayURI:  String?

    // App Remote
    private lazy var appRemote: SPTAppRemote = {
        let config = SPTConfiguration(clientID: clientId, redirectURL: URL(string: redirectURI)!)
        let remote = SPTAppRemote(configuration: config, logLevel: .none)
        remote.delegate = self
        return remote
    }()

    override init() {
        super.init()
        loadFromKeychain()
        if accessToken != nil {
            appRemote.connectionParameters.accessToken = accessToken
        }
    }

    // MARK: - URL callback (called from SamajhApp .onOpenURL)

    func handleURL(_ url: URL) {
        guard url.scheme == "samajh" else { return }
        // App Remote auth token comes back here on first authorizeAndPlayURI
        let params = appRemote.authorizationParameters(from: url)
        if let token = params?[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            KV.set(token, for: "spotify.access")
            appRemote.connectionParameters.accessToken = token
            isAuthorized = true
            appRemote.connect()
        }
    }

    // MARK: - Lifecycle

    func appDidBecomeActive() {
        guard accessToken != nil, !appRemote.isConnected else { return }
        appRemote.connect()
    }

    func appDidEnterBackground() {
        guard appRemote.isConnected else { return }
        appRemote.disconnect()
    }

    // MARK: - Play

    /// Find the song on Spotify and play it via App Remote without leaving the app.
    func play(title: String, artist: String) async {
        if !isAuthorized {
            try? await authenticate()
            guard isAuthorized else { return }
        }

        isBusy = true
        defer { isBusy = false }

        guard let uri = await searchTrackURI(title: title, artist: artist) else { return }

        nowPlayingTitle = title
        appRemote.connectionParameters.accessToken = accessToken

        if appRemote.isConnected {
            appRemote.playerAPI?.play(uri, callback: { _, _ in })
        } else {
            pendingPlayURI = uri
            appRemote.connect()
        }
    }

    // MARK: - Spotify Web API PKCE auth (for search + initial token)

    func authenticate() async throws {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false; activeSession = nil }

        codeVerifier = PKCE.generateVerifier()

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",             value: clientId),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "scope",                 value: "user-read-currently-playing app-remote-control streaming"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: PKCE.challenge(for: codeVerifier)),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: "samajh") { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: SpotifyError.cancelled) }
            }
            session.presentationContextProvider = PresentationProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw SpotifyError.noCode }

        try await exchangeCode(code)

        // After PKCE auth, prime App Remote with the same token
        appRemote.connectionParameters.accessToken = accessToken
    }

    func disconnect() {
        if appRemote.isConnected { appRemote.disconnect() }
        accessToken = nil; refreshToken = nil; expiresAt = nil
        isAuthorized = false; isConnected = false
        KV.delete("spotify.access"); KV.delete("spotify.refresh"); KV.delete("spotify.expires")
    }

    // MARK: - Currently Playing

    func currentlyPlaying() async throws -> SpotifyTrack? {
        guard let token = try? await validToken() else { throw SpotifyError.notAuthorized }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct CPResp: Decodable {
            struct Item: Decodable {
                let id: String
                let name: String
                struct Artist: Decodable { let name: String }
                let artists: [Artist]
                struct Album: Decodable {
                    struct Image: Decodable { let url: String }
                    let images: [Image]
                }
                let album: Album
            }
            let item: Item?
        }

        guard let resp = try? JSONDecoder().decode(CPResp.self, from: data),
              let item = resp.item else { return nil }
        return SpotifyTrack(
            id: item.id,
            name: item.name,
            artist: item.artists.first?.name ?? "",
            imageUrl: item.album.images.first?.url
        )
    }

    // MARK: - Search

    private func searchTrackURI(title: String, artist: String) async -> String? {
        guard let token = try? await validToken() else { return nil }

        let query = "\(title) \(artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(query)&type=track&limit=1") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }

        struct Resp: Decodable {
            struct Tracks: Decodable {
                struct Item: Decodable { let uri: String }
                let items: [Item]
            }
            let tracks: Tracks
        }
        return (try? JSONDecoder().decode(Resp.self, from: data))?.tracks.items.first?.uri
    }

    // MARK: - Token management

    private func validToken() async throws -> String {
        if let expires = expiresAt, expires < Date().addingTimeInterval(60) {
            try await doRefresh()
        }
        guard let token = accessToken else { throw SpotifyError.notAuthorized }
        return token
    }

    private func exchangeCode(_ code: String) async throws {
        try await tokenRequest([
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
            "client_id":     clientId,
            "code_verifier": codeVerifier,
        ])
    }

    private func doRefresh() async throws {
        guard let refresh = refreshToken else { throw SpotifyError.notAuthorized }
        do {
            try await tokenRequest([
                "grant_type":    "refresh_token",
                "refresh_token": refresh,
                "client_id":     clientId,
            ])
        } catch {
            disconnect()
            throw SpotifyError.notAuthorized
        }
    }

    private func tokenRequest(_ params: [String: String]) async throws {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        struct TokenResp: Decodable {
            let accessToken: String
            let expiresIn: Int
            let refreshToken: String?
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case expiresIn   = "expires_in"
                case refreshToken = "refresh_token"
            }
        }

        let (data, _) = try await URLSession.shared.data(for: req)
        let tokens = try JSONDecoder().decode(TokenResp.self, from: data)
        accessToken = tokens.accessToken
        if let r = tokens.refreshToken { refreshToken = r }
        expiresAt = Date().addingTimeInterval(Double(tokens.expiresIn))
        isAuthorized = true
        KV.set(accessToken!, for: "spotify.access")
        if let r = refreshToken { KV.set(r, for: "spotify.refresh") }
        KV.set(ISO8601DateFormatter().string(from: expiresAt!), for: "spotify.expires")
    }

    private func loadFromKeychain() {
        accessToken  = KV.get("spotify.access")
        refreshToken = KV.get("spotify.refresh")
        if let s = KV.get("spotify.expires") { expiresAt = ISO8601DateFormatter().date(from: s) }
        isAuthorized = accessToken != nil
    }
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyManager: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { await MainActor.run {
            self.isConnected = true
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { _, _ in })
            if let uri = self.pendingPlayURI {
                self.pendingPlayURI = nil
                appRemote.playerAPI?.play(uri, callback: { _, _ in })
            }
        }}
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { await MainActor.run { self.isConnected = false } }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { await MainActor.run {
            self.isConnected = false
            // Spotify isn't running — launch it with the pending URI (brief app switch)
            if let uri = self.pendingPlayURI {
                self.pendingPlayURI = nil
                appRemote.authorizeAndPlayURI(uri, completionHandler: nil)
            }
        }}
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate

extension SpotifyManager: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { await MainActor.run {
            self.isPlaying = !playerState.isPaused
            if playerState.isPaused { self.nowPlayingTitle = nil }
        }}
    }
}
