import SwiftUI

@MainActor
final class GenerationQueue: ObservableObject {

    struct PendingJob: Identifiable, Codable {
        let id: String      // jobId
        let title: String
        let imageUrl: String?
    }

    @Published var pendingJobs: [PendingJob] = []
    @Published var errorMessage: String?

    var isGenerating: Bool { !pendingJobs.isEmpty }

    private static let storageKey = "pendingGenerationJobs"
    private var errorClearTask: Task<Void, Never>?

    func dismissError() {
        errorMessage = nil
        errorClearTask?.cancel()
    }

    private func setError(_ message: String) {
        errorMessage = message
        errorClearTask?.cancel()
        errorClearTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { errorMessage = nil }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([PendingJob].self, from: data) {
            pendingJobs = saved
            for job in saved {
                Task { await poll(jobId: job.id, title: job.title, imageUrl: job.imageUrl, onComplete: { _ in }) }
            }
        }
    }

    func start(
        rawLyrics: String,
        titleHint: String,
        artistHint: String,
        imageUrl: String? = nil,
        onComplete: @escaping (String) -> Void
    ) {
        errorMessage = nil
        Task {
            do {
                let queued = try await APIClient.shared.jsonifyLyrics(
                    rawLyrics: rawLyrics,
                    titleHint: titleHint.isEmpty ? nil : titleHint,
                    artistHint: artistHint.isEmpty ? nil : artistHint,
                    imageUrl: imageUrl
                )
                let job = PendingJob(id: queued.jobId, title: titleHint, imageUrl: imageUrl)
                pendingJobs.append(job)
                persist()
                await poll(jobId: queued.jobId, title: titleHint, imageUrl: imageUrl, onComplete: onComplete)
            } catch {
                setError(error.localizedDescription)
            }
        }
    }

    func retranslateSong(songId: String, title: String, imageUrl: String? = nil, feedback: String?) {
        errorMessage = nil
        Task {
            do {
                let queued = try await APIClient.shared.retranslateSong(songId: songId, feedback: feedback)
                let job = PendingJob(id: queued.jobId, title: title, imageUrl: imageUrl)
                pendingJobs.append(job)
                persist()
                await poll(jobId: queued.jobId, title: title, imageUrl: imageUrl, onComplete: { _ in })
            } catch {
                setError(error.localizedDescription)
            }
        }
    }

    private func poll(jobId: String, title: String, imageUrl: String? = nil, onComplete: @escaping (String) -> Void) async {
        defer {
            pendingJobs.removeAll { $0.id == jobId }
            persist()
        }

        while true {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if Task.isCancelled { return }

            do {
                let status = try await APIClient.shared.getJobStatus(jobId: jobId)
                switch status.status {
                case "done":
                    if let songId = status.songId { onComplete(songId) }
                    return
                case "error":
                    setError(status.errorMessage ?? "\(title): generation failed")
                    return
                default:
                    break
                }
            } catch {
                // Network hiccup — keep polling.
            }
        }
    }

    private func persist() {
        let data = try? JSONEncoder().encode(pendingJobs)
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
