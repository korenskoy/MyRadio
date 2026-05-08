import Foundation
import RadioBrowserKit

actor Persistence {
    private let directory: URL
    private let backupDirectory: URL
    private let maxBackups = 3

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("MyRadio", isDirectory: true)
        backupDirectory = directory.appendingPathComponent("backups", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Favorites

    func loadFavorites() -> Set<String> {
        load("favorites.json") ?? []
    }

    func saveFavorites(_ favorites: Set<String>) {
        save(favorites, to: "favorites.json")
    }

    func loadFavoriteStations() -> [String: Station] {
        load("favorite-stations.json") ?? [:]
    }

    func saveFavoriteStations(_ stations: [String: Station]) {
        save(stations, to: "favorite-stations.json")
    }

    // MARK: - History

    func loadHistory() -> [HistoryEntry] {
        load("history.json") ?? []
    }

    func saveHistory(_ history: [HistoryEntry]) {
        save(history, to: "history.json")
    }

    // MARK: - Preferences (volume + active tab)

    func loadPreferences() -> Preferences? {
        load("preferences.json")
    }

    func savePreferences(_ prefs: Preferences) {
        save(prefs, to: "preferences.json")
    }

    // MARK: - Custom stations

    func loadCustomStations() -> [CustomStation] {
        load("custom-stations.json") ?? []
    }

    func saveCustomStations(_ stations: [CustomStation]) {
        save(stations, to: "custom-stations.json")
    }

    // MARK: - Generic load/save with rolling backup

    private func load<T: Decodable>(_ filename: String) -> T? {
        let url = directory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) {
            do {
                return try JSONDecoder.app.decode(T.self, from: data)
            } catch {
                // Primary corrupted — try backups
                return loadFromBackup(filename)
            }
        }
        return loadFromBackup(filename)
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

    private func save<T: Encodable>(_ value: T, to filename: String) {
        let url = directory.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder.app.encode(value)
            rotateBackups(for: filename, primaryURL: url)
            try data.write(to: url, options: .atomic)
        } catch {
            // Never silently discard — keep old file intact
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
}

// MARK: - Preferences model

struct Preferences: Codable {
    var volume: Float
    var activeTab: TabKind
}

// MARK: - Coders

private extension JSONDecoder {
    static let app: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

private extension JSONEncoder {
    static let app: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
