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

    private let baseURL = URL(string: "https://humdard-lyric-api.sh0vel.workers.dev/api/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Double.greatestFiniteMagnitude
        config.timeoutIntervalForResource = Double.greatestFiniteMagnitude
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func listSongs() async throws -> [SongMetadata] {
        let url = baseURL.appendingPathComponent("/songs")
        let response: SongsListResponse = try await request(url: url, method: "GET", body: Optional<String>.none)
        return response.songs
    }

    func getSong(songId: String, includeTokens: Bool = true) async throws -> LyricLesson {
        var components = URLComponents(url: baseURL.appendingPathComponent("/songs/\(songId)"), resolvingAgainstBaseURL: false)!
        if !includeTokens {
            components.queryItems = [URLQueryItem(name: "tokens", value: "false")]
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return try await request(url: url, method: "GET", body: Optional<String>.none)
    }

    func lookupLyrics(title: String, artist: String?) async throws -> [LookupCandidate] {
        let url = baseURL.appendingPathComponent("/lookup")
        let payload = LookupRequest(
            title: title,
            artist: artist?.isEmpty == true ? nil : artist
        )
        let response: LookupResponse = try await request(url: url, method: "POST", body: payload)
        return response.candidates
    }

    func jsonifyLyrics(rawLyrics: String, titleHint: String?, artistHint: String?, imageUrl: String? = nil) async throws -> JsonifyQueuedResponse {
        let url = baseURL.appendingPathComponent("/jsonify")
        let payload = JsonifyRequest(
            rawLyrics: rawLyrics,
            titleHint: titleHint?.isEmpty == true ? nil : titleHint,
            artistHint: artistHint?.isEmpty == true ? nil : artistHint,
            imageUrl: imageUrl
        )
        return try await request(url: url, method: "POST", body: payload)
    }

    func getJobStatus(jobId: String) async throws -> JobStatusResponse {
        let url = baseURL.appendingPathComponent("/jobs/\(jobId)")
        return try await request(url: url, method: "GET", body: Optional<String>.none)
    }

    func insertInstrumental(songId: String, beforeLineId: String) async throws {
        let url = baseURL.appendingPathComponent("/songs/\(songId)/lines/\(beforeLineId)/instrumental")
        let _: EmptyResponse = try await request(url: url, method: "POST", body: Optional<String>.none)
    }

    func deleteLine(songId: String, lineId: String) async throws {
        let url = baseURL.appendingPathComponent("/songs/\(songId)/lines/\(lineId)")
        let _: EmptyResponse = try await request(url: url, method: "DELETE", body: Optional<String>.none)
    }

    func updateLine(songId: String, lineId: String, fields: LineUpdateRequest) async throws {
        let url = baseURL.appendingPathComponent("/songs/\(songId)/lines/\(lineId)")
        let _: EmptyResponse = try await request(url: url, method: "PATCH", body: fields)
    }

    func retranslateLine(songId: String, lineId: String, feedback: String?) async throws -> LineTranslationResult {
        let url = baseURL.appendingPathComponent("/songs/\(songId)/lines/\(lineId)/retranslate")
        let payload = FeedbackRequest(feedback: feedback)
        return try await request(url: url, method: "POST", body: payload)
    }

    func retranslateSong(songId: String, feedback: String?) async throws -> JsonifyQueuedResponse {
        let url = baseURL.appendingPathComponent("/songs/\(songId)/retranslate")
        let payload = FeedbackRequest(feedback: feedback)
        return try await request(url: url, method: "POST", body: payload)
    }

    func spotifySearch(query: String) async throws -> [SpotifyTrack] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/spotify/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { throw APIError.invalidURL }
        struct Resp: Decodable { let tracks: [SpotifyTrack] }
        let resp: Resp = try await request(url: url, method: "GET", body: Optional<String>.none)
        return resp.tracks
    }

    func deleteSong(songId: String) async throws {
        let url = baseURL.appendingPathComponent("/songs/\(songId)")
        let _: EmptyResponse = try await request(url: url, method: "DELETE", body: Optional<String>.none)
    }

    func getFavorites() async throws -> [FavoriteLine] {
        let url = baseURL.appendingPathComponent("/favorites")
        struct Resp: Decodable { let favorites: [FavoriteLine] }
        let resp: Resp = try await request(url: url, method: "GET", body: Optional<String>.none)
        return resp.favorites
    }

    func addFavorite(_ line: FavoriteLine) async throws {
        let url = baseURL.appendingPathComponent("/favorites")
        let _: EmptyResponse = try await request(url: url, method: "POST", body: line)
    }

    func removeFavorite(lineId: String) async throws {
        let url = baseURL.appendingPathComponent("/favorites/\(lineId)")
        let _: EmptyResponse = try await request(url: url, method: "DELETE", body: Optional<String>.none)
    }

    private func request<Body: Encodable, T: Decodable>(url: URL, method: String, body: Body?) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)
        }
        if let token = await AuthManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
