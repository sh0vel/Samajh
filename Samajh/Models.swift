import Foundation

struct SongMetadata: Codable, Identifiable, Hashable {
    let songId: String
    let title: String
    let artist: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { songId }
}

struct SongsListResponse: Codable {
    let songs: [SongMetadata]
}

struct LyricLesson: Codable {
    let lessonId: String?
    let title: String
    let source: LessonSource?
    let sections: [LyricSection]
}

struct LessonSource: Codable {
    let artist: String?
}

struct LyricSection: Codable, Identifiable {
    let sectionId: String
    let label: String?
    let order: Int?
    let lines: [LyricLineModel]

    var id: String { sectionId }
}

struct LyricLineModel: Codable, Identifiable {
    let lineId: String
    let order: Int?
    let text: LineText
    let tokens: [LyricToken]?

    var id: String { lineId }
}

struct LineText: Codable {
    let target: String
    let roman: String
    let wordByWord: String?
    let direct: String?
    let natural: String?
}

struct LyricToken: Codable, Identifiable, Hashable {
    let id: String
    let surface: String
    let roman: String
    let gloss: String
}

struct JsonifyRequest: Codable {
    let rawLyrics: String
    let titleHint: String?
    let artistHint: String?
}

struct JsonifyResponse: Codable {
    let songId: String
}

struct LookupRequest: Codable {
    let title: String
    let artist: String?
}

struct LookupCandidate: Codable, Identifiable, Hashable {
    let title: String
    let artist: String
    let devanagari: String
    let confidence: String
    let notes: String

    var id: String { devanagari }
}

struct LookupResponse: Codable {
    let candidates: [LookupCandidate]
}

struct APIErrorPayload: Codable {
    struct Inner: Codable {
        let code: String?
        let message: String?
    }
    let error: Inner?
}
