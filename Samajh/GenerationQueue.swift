import SwiftUI

@MainActor
final class GenerationQueue: ObservableObject {

    struct PendingJob: Identifiable, Codable {
        let id: String      // jobId
        let title: String
        let imageUrl: String?
        let createdAt: Date
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
        // Restore from UserDefaults immediately (with staleness check) so UI isn't blank
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([PendingJob].self, from: data) {
            let cutoff = Date().addingTimeInterval(-15 * 60)
            pendingJobs = saved.filter { $0.createdAt > cutoff }
        }

        // Then sync from server — server is truth
        Task {
            do {
                let serverJobs = try await APIClient.shared.getPendingJobs()
                let serverPending = serverJobs
                    .filter { $0.status == "pending" }
                    .map { PendingJob(id: $0.jobId, title: $0.title ?? $0.jobId, imageUrl: $0.imageUrl, createdAt: Date()) }

                // Replace local state with server truth (drops any stale UserDefaults-only jobs)
                pendingJobs = serverPending
                persist()

                for job in pendingJobs {
                    Task { await poll(jobId: job.id, title: job.title, imageUrl: job.imageUrl, onComplete: { _ in }) }
                }
            } catch {
                // Network unavailable — poll whatever survived the staleness check
                for job in pendingJobs {
                    Task { await poll(jobId: job.id, title: job.title, imageUrl: job.imageUrl, onComplete: { _ in }) }
                }
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
                let job = PendingJob(id: queued.jobId, title: titleHint, imageUrl: imageUrl, createdAt: Date())
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
                let job = PendingJob(id: queued.jobId, title: title, imageUrl: imageUrl, createdAt: Date())
                pendingJobs.append(job)
                persist()
                await poll(jobId: queued.jobId, title: title, imageUrl: imageUrl, onComplete: { _ in })
            } catch {
                setError(error.localizedDescription)
            }
        }
    }

    func cancel(jobId: String) {
        pendingJobs.removeAll { $0.id == jobId }
        persist()
    }

    private func poll(jobId: String, title: String, imageUrl: String? = nil, onComplete: @escaping (String) -> Void) async {
        defer {
            pendingJobs.removeAll { $0.id == jobId }
            persist()
        }

        let deadline = Date().addingTimeInterval(10 * 60)
        while true {
            if Task.isCancelled { return }
            if Date() > deadline {
                setError("\(title): timed out — please try again")
                return
            }
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
            } catch let error as APIError {
                switch error {
                case .transport: break  // network hiccup — keep polling
                default: setError(error.localizedDescription); return
                }
            } catch {
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private func persist() {
        let data = try? JSONEncoder().encode(pendingJobs)
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
