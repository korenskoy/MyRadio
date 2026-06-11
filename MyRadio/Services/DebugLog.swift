import Foundation
import RadioBrowserKit

@MainActor
@Observable
final class DebugLog {
    private let capacity: Int

    private(set) var entries: [LogEntry] = []
    var logsNewestFirst: Bool = false

    init(capacity: Int = 500) {
        self.capacity = capacity
    }

    /// Safe to call from any thread/actor (RBK logger callbacks, the persistence
    /// actor, AVFoundation observers). The entry is built off-main but the
    /// `@Observable` mutation is funneled onto the main actor, so SwiftUI reads
    /// and writes never race.
    nonisolated func append(_ level: LogEntry.Level, _ message: String, source: String) {
        let entry = LogEntry(
            time: Self.timestamp(),
            level: level,
            message: message,
            source: source
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.capacity {
                self.entries.removeFirst(self.entries.count - self.capacity)
            }
        }
    }

    func clear() {
        entries.removeAll()
    }

    func asText() -> String {
        entries
            .map { "[\($0.time)] [\($0.level.rawValue.uppercased())] \($0.message)  \($0.source)" }
            .joined(separator: "\n")
    }

    // DateFormatter is thread-safe for formatting (macOS 10.9+) and only ever
    // read here, so sharing it across `append` callers is fine.
    nonisolated private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    nonisolated private static func timestamp() -> String {
        formatter.string(from: Date())
    }
}

// MARK: - LogEntry

struct LogEntry: Identifiable {
    let id = UUID()
    let time: String
    let level: Level
    let message: String
    let source: String

    enum Level: String, CaseIterable {
        case debug, info, warn, error
    }
}

// MARK: - RadioBrowserKit LoggerProtocol bridge

final class RBKLogBridge: LoggerProtocol {
    private let log: DebugLog

    init(_ log: DebugLog) { self.log = log }

    func log(_ level: LogLevel, _ category: LogCategory, _ message: @autoclosure () -> String) {
        let mapped: LogEntry.Level = switch level {
        case .trace, .debug: .debug
        case .info, .notice: .info
        case .warn:          .warn
        case .error:         .error
        }
        log.append(mapped, message(), source: "rb.\(category.rawValue.lowercased())")
    }
}
