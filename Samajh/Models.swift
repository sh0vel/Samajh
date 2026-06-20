import Foundation

struct SongMetadata: Codable, Identifiable, Hashable {
    let songId: String
    let title: String
    let artist: String?
    let imageUrl: String?
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
    let isInstrumental: Bool?
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
    let definition: String?
    let spectrum: String?
    let songContext: String?
}

struct JsonifyRequest: Codable {
    let rawLyrics: String
    let titleHint: String?
    let artistHint: String?
    let imageUrl: String?
}

struct JsonifyQueuedResponse: Codable {
    let jobId: String
}

struct JsonifyResponse: Codable {
    let songId: String
}

struct JobStatusResponse: Codable {
    let jobId: String
    let status: String
    let songId: String?
    let errorMessage: String?
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

struct LineUpdateRequest: Codable {
    var roman: String?
    var wordByWord: String?
    var direct: String?
    var natural: String?
}

struct FeedbackRequest: Codable {
    let feedback: String?
}

struct LineTranslationResult: Codable {
    let roman: String
    let wordByWord: String
    let direct: String
    let natural: String
    let tokens: [LyricToken]
}

struct EmptyResponse: Codable {
    let ok: Bool?
}
