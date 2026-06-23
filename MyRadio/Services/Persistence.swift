import Foundation
import RadioBrowserKit

enum PersistenceError: Error {
    /// A data file exists on disk but neither it nor any backup could be
    /// decoded. The corrupt primary has been archived to `corrupted/` and the
    /// caller MUST NOT overwrite the in-memory state with an empty default.
    case corrupted(String)
}

actor Persistence {
    private let directory: URL
    private let backupDirectory: URL
    private let corruptedDirectory: URL
    private let maxBackups = 3

    /// Monotonic per-file write generation. A `save(...)` whose generation is
    /// older than the latest one already applied for that file is dropped —
    /// this keeps two rapidly-scheduled writes from landing out of order and
    /// resurrecting stale state.
    private var lastWriteGen: [String: Int] = [:]

    /// Surfaces non-fatal I/O problems (failed write, corrupted file) to the
    /// app's debug log. Hops to the log on whatever thread it was given.
    private var logError: (@Sendable (String) -> Void)?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("MyRadio", isDirectory: true)
        backupDirectory = directory.appendingPathComponent("backups", isDirectory: true)
        corruptedDirectory = directory.appendingPathComponent("corrupted", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: corruptedDirectory, withIntermediateDirectories: true)
    }

    func setErrorLogger(_ logger: @escaping @Sendable (String) -> Void) {
        self.logError = logger
    }

    // MARK: - Favorites

    func loadFavorites() throws -> [String] {
        try load("favorites.json") ?? []
    }

    func saveFavorites(_ favorites: [String], generation: Int) {
        save(favorites, to: "favorites.json", generation: generation)
    }

    func loadFavoriteStations() throws -> [String: Station] {
        try load("favorite-stations.json") ?? [:]
    }

    func saveFavoriteStations(_ stations: [String: Station], generation: Int) {
        save(stations, to: "favorite-stations.json", generation: generation)
    }

    // MARK: - History

    func loadHistory() throws -> [HistoryEntry] {
        try load("history.json") ?? []
    }

    func saveHistory(_ history: [HistoryEntry], generation: Int) {
        save(history, to: "history.json", generation: generation)
    }

    /// Synchronous, blocking history write for the app-termination path, where
    /// awaiting the actor is impossible. Bypasses backups/generation — the app
    /// is going away and this is the authoritative final snapshot.
    nonisolated func saveHistorySync(_ history: [HistoryEntry]) {
        let url = directory.appendingPathComponent("history.json")
        guard let data = try? JSONEncoder.app.encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Preferences (volume + active tab)

    func loadPreferences() throws -> Preferences? {
        try load("preferences.json")
    }

    func savePreferences(_ prefs: Preferences, generation: Int) {
        save(prefs, to: "preferences.json", generation: generation)
    }

    /// Synchronous preferences write for the app-termination path.
    nonisolated func savePreferencesSync(_ prefs: Preferences) {
        let url = directory.appendingPathComponent("preferences.json")
        guard let data = try? JSONEncoder.app.encode(prefs) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func resetPreferences() {
        let url = directory.appendingPathComponent("preferences.json")
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated var directoryURL: URL { directory }

    // MARK: - Custom stations

    func loadCustomStations() throws -> [CustomStation] {
        try load("custom-stations.json") ?? []
    }

    func saveCustomStations(_ stations: [CustomStation], generation: Int) {
        save(stations, to: "custom-stations.json", generation: generation)
    }

    // MARK: - Generic load/save with rolling backup

    /// - Returns `nil` when no data file (and no backups) exist — a legitimate
    ///   first-run / empty state that is safe to overwrite.
    /// - Throws `PersistenceError.corrupted` when a file exists but neither it
    ///   nor any backup can be decoded. The corrupt primary is archived first.
    private func load<T: Decodable>(_ filename: String) throws -> T? {
        let url = directory.appendingPathComponent(filename)

        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder.app.decode(T.self, from: data) {
                return decoded
            }
            // Primary exists but won't decode — try backups before giving up.
            if let fromBackup: T = loadFromBackup(filename) {
                logError?("Primary \(filename) unreadable; recovered from backup")
                return fromBackup
            }
            // Nothing decodes. Archive the corrupt primary so the user's data is
            // never silently destroyed, then signal the caller to NOT overwrite.
            archiveCorrupted(filename, primaryURL: url)
            logError?("\(filename) is corrupted and no backup is readable; archived to corrupted/. Keeping in-memory state to avoid data loss.")
            throw PersistenceError.corrupted(filename)
        }

        // No primary file — a backup may still exist (primary deleted/never written).
        if let fromBackup: T = loadFromBackup(filename) {
            return fromBackup
        }
        return nil
    }

    private func loadFromBackup<T: Decodable>(_ filename: String) -> T? {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        for i in 1...maxBackups {
            let backupURL = backupDirectory.appendingPathComponent("\(base).\(i).\(ext)")
            guard let data = try? Data(contentsOf: backupURL) else { continue }
            if let result = try? JSONDecoder.app.decode(T.self, from: data) {
                return result
            }
        }
        return nil
    }

    /// Copies (not moves) the corrupt primary into `corrupted/` with a timestamp
    /// so it survives subsequent backup rotation and stays available for manual
    /// recovery.
    private func archiveCorrupted(_ filename: String, primaryURL: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: primaryURL.path) else { return }
        let dst = corruptedDirectory.appendingPathComponent("\(filename).\(Self.archiveStamp()).bak")
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: primaryURL, to: dst)
    }

    private func save<T: Encodable>(_ value: T, to filename: String, generation: Int) {
        // Drop stale writes: a newer snapshot has already been applied for this file.
        if let last = lastWriteGen[filename], generation < last { return }
        lastWriteGen[filename] = max(lastWriteGen[filename] ?? 0, generation)

        let url = directory.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder.app.encode(value)
            rotateBackups(for: filename, primaryURL: url)
            try data.write(to: url, options: .atomic)
        } catch {
            // Old file is left intact; surface the failure instead of pretending it saved.
            logError?("Failed to save \(filename): \(error.localizedDescription)")
        }
    }

    private func rotateBackups(for filename: String, primaryURL: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: primaryURL.path) else { return }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        // Shift existing backups: 2→3, 1→2
        for i in stride(from: maxBackups - 1, through: 1, by: -1) {
            let src = backupDirectory.appendingPathComponent("\(base).\(i).\(ext)")
            let dst = backupDirectory.appendingPathComponent("\(base).\(i + 1).\(ext)")
            try? fm.removeItem(at: dst)
            try? fm.moveItem(at: src, to: dst)
        }

        // Copy current → backup.1
        let backup1 = backupDirectory.appendingPathComponent("\(base).1.\(ext)")
        try? fm.removeItem(at: backup1)
        try? fm.copyItem(at: primaryURL, to: backup1)
    }

    private static func archiveStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - Preferences model

struct Preferences: Codable {
    var volume: Float
    var activeTab: TabKind
    var theme: AppTheme?
    var accent: AccentName?
    var language: AppLanguage?
    var launchAtLogin: Bool?
    var restoreLastStation: Bool?
    var confirmQuit: Bool?
    var lastStationUUID: String?
    var wasPlaying: Bool?
}

extension AppTheme: Codable {}
extension AccentName: Codable {}

// MARK: - Coders

private extension JSONDecoder {
    nonisolated static let app: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

private extension JSONEncoder {
    nonisolated static let app: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
