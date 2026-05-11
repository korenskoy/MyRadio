import Foundation

@MainActor
@Observable
final class SleepTimerService {
    var endDate: Date?
    private(set) var totalDuration: TimeInterval = 0
    var remainingSeconds: TimeInterval = 0
    var onFire: (() -> Void)?

    var isActive: Bool { endDate != nil }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - remainingSeconds / totalDuration))
    }

    private var timerTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    func schedule(minutes: Double) {
        cancel()
        let duration = minutes * 60
        totalDuration = duration
        remainingSeconds = duration
        endDate = Date().addingTimeInterval(duration)

        tickTask = Task { [weak self] in
            while true {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { break }
                guard let self else { break }
                self.remainingSeconds = max(0, self.endDate?.timeIntervalSinceNow ?? 0)
            }
        }

        timerTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(duration)) }
            catch { return }
            guard let self else { return }
            self.endDate = nil
            self.remainingSeconds = 0
            self.onFire?()
        }
    }

    func cancel() {
        timerTask?.cancel()
        tickTask?.cancel()
        timerTask = nil
        tickTask = nil
        endDate = nil
        remainingSeconds = 0
        totalDuration = 0
    }
}
