import Foundation
import RadioBrowserKit

@Observable
final class DebugLog: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int

    private(set) var entries: [LogEntry] = []

    init(capacity: Int = 500) {
        self.capacity = capacity
    }

    func append(_ level: LogEntry.Level, _ message: String, source: String) {
        let entry = LogEntry(
            time: Self.timestamp(),
            level: level,
            message: message,
            source: source
        )
        lock.withLock {
            entries.append(entry)
            if entries.count > capacity {
                entries.removeFirst(entries.count - capacity)
            }
        }
    }

    func clear() {
        lock.withLock { entries.removeAll() }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static func timestamp() -> String {
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
