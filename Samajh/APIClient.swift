import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case decoding(Error)
    case transport(Error)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let err): return "Decoding error: \(err.localizedDescription)"
        case .transport(let err): return err.localizedDescription
        case .message(let msg): return msg
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://humdard-lyric-api.sh0vel.workers.dev")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Double.greatestFiniteMagnitude
        config.timeoutIntervalForResource = Double.greatestFiniteMagnitude
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func listSongs() async throws -> [SongMetadata] {
        let url = baseURL.appendingPathComponent("/api/songs")
        let response: SongsListResponse = try await request(url: url, method: "GET", body: Optional<String>.none)
        return response.songs
    }

    func getSong(songId: String, includeTokens: Bool = true) async throws -> LyricLesson {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/songs/\(songId)"), resolvingAgainstBaseURL: false)!
        if !includeTokens {
            components.queryItems = [URLQueryItem(name: "tokens", value: "false")]
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return try await request(url: url, method: "GET", body: Optional<String>.none)
    }

    func lookupLyrics(title: String, artist: String?) async throws -> [LookupCandidate] {
        let url = baseURL.appendingPathComponent("/api/lookup")
        let payload = LookupRequest(
            title: title,
            artist: artist?.isEmpty == true ? nil : artist
        )
        let response: LookupResponse = try await request(url: url, method: "POST", body: payload)
        return response.candidates
    }

    func jsonifyLyrics(rawLyrics: String, titleHint: String?, artistHint: String?) async throws -> JsonifyResponse {
        let url = baseURL.appendingPathComponent("/api/jsonify")
        let payload = JsonifyRequest(
            rawLyrics: rawLyrics,
            titleHint: titleHint?.isEmpty == true ? nil : titleHint,
            artistHint: artistHint?.isEmpty == true ? nil : artistHint
        )
        return try await request(url: url, method: "POST", body: payload)
    }

    private func request<Body: Encodable, T: Decodable>(url: URL, method: String, body: Body?) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(0, "No response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? decoder.decode(APIErrorPayload.self, from: data),
               let msg = err.error?.message {
                throw APIError.message(msg)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
