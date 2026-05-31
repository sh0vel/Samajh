import Foundation
import AuthenticationServices
import Security
import CryptoKit
import UIKit

// MARK: - Public model

struct SpotifyTrack: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let artist: String
    let imageUrl: String?
}

// MARK: - Error

enum SpotifyError: LocalizedError {
    case notAuthorized, cancelled, noCode

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Not connected to Spotify"
        case .cancelled:     return "Spotify login cancelled"
        case .noCode:        return "No authorization code received"
        }
    }
}

// MARK: - Private API response types

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct SpotifyCurrentlyPlayingResponse: Decodable {
    let isPlaying: Bool
    let item: SpotifyAPITrack?
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
    }
}

private struct SpotifyAPITrack: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyAPIArtist]
    let album: SpotifyAPIAlbum?
}

private struct SpotifyAPIArtist: Decodable { let name: String }

private struct SpotifyAPIAlbum: Decodable {
    let images: [SpotifyAPIImage]
}

private struct SpotifyAPIImage: Decodable {
    let url: String
    let height: Int?
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
final class SpotifyManager: ObservableObject {

    private let clientId    = "55c2275c63634074aa13b4d40e359e6f"
    private let redirectURI = "samajh://spotify-callback"

    @Published var isAuthorized = false

    private var accessToken:   String?
    private var refreshToken:  String?
    private var expiresAt:     Date?

    private var codeVerifier     = ""
    private var isAuthenticating = false
    private var activeSession:   ASWebAuthenticationSession?

    init() { Task { self.loadFromKeychain() } }

    // MARK: - Auth

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
            URLQueryItem(name: "scope",                 value: "user-read-currently-playing"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: PKCE.challenge(for: codeVerifier)),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: "samajh"
            ) { url, error in
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
    }

    func disconnect() {
        accessToken = nil; refreshToken = nil; expiresAt = nil
        isAuthorized = false
        KV.delete("spotify.access"); KV.delete("spotify.refresh"); KV.delete("spotify.expires")
    }

    // MARK: - API

    func currentlyPlaying() async throws -> SpotifyTrack? {
        let token = try await validToken()
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        if (response as? HTTPURLResponse)?.statusCode == 204 { return nil }
        let result = try JSONDecoder().decode(SpotifyCurrentlyPlayingResponse.self, from: data)
        guard result.isPlaying, let track = result.item else { return nil }
        let smallestImage = track.album?.images.min(by: { ($0.height ?? 0) < ($1.height ?? 0) })?.url
        let artistNames = track.artists.map(\.name).joined(separator: ", ")
        return SpotifyTrack(id: track.id, name: track.name, artist: artistNames, imageUrl: smallestImage)
    }

    // MARK: - Tokens

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
        let (data, _) = try await URLSession.shared.data(for: req)
        let tokens = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
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
