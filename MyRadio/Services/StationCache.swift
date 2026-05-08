import Foundation
import RadioBrowserKit

actor StationCache {
    private let api: RadioBrowserAPI
    private let cacheDir: URL
    private let ttl: TimeInterval = 86400
    private let log: DebugLog

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    init(api: RadioBrowserAPI, log: DebugLog) {
        self.api = api
        self.log = log
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = caches.appendingPathComponent("MyRadio/api", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Stations

    func topVoted(_ count: Int = 50) async -> [Station] {
        await cached("topVoted-\(count)") { await self.api.topVoted(count) }
    }

    func topClicked(_ count: Int = 50) async -> [Station] {
        await cached("topClicked-\(count)") { await self.api.topClicked(count) }
    }

    func search(name: String, limit: Int = 100) async -> [Station] {
        let safeKey = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        return await cached("search-\(safeKey)-\(limit)") {
            await self.api.search(name: name, limit: limit)
        }
    }

    func stationsByTag(_ tag: String, limit: Int = 100) async -> [Station] {
        let safeKey = tag.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? tag
        return await cached("tag-\(safeKey)-\(limit)") {
            await self.api.stationsByTag(tag, limit: limit)
        }
    }

    func stationsByCountry(_ name: String, limit: Int = 100) async -> [Station] {
        let safeKey = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        return await cached("country-\(safeKey)-\(limit)") {
            await self.api.stationsByCountry(name, limit: limit)
        }
    }

    func stationsByURL(_ url: String) async -> [Station] {
        await api.stationsByURL(url)
    }

    func stationsWithGeo(limit: Int = 500) async -> [Station] {
        await cached("geo-\(limit)") { await self.api.stationsWithGeo(limit: limit) }
    }

    // MARK: - Metadata

    func tags(limit: Int = 200) async -> [NamedCount] {
        await cached("tags-\(limit)") { await self.api.tags(limit: limit) }
    }

    func countries(limit: Int = 200) async -> [NamedCount] {
        await cached("countries-\(limit)") { await self.api.countries(limit: limit) }
    }

    // MARK: - Pass-through

    func registerClick(stationUUID: String) async {
        await api.registerClick(stationUUID: stationUUID)
    }

    func registerVote(stationUUID: String) async {
        await api.registerVote(stationUUID: stationUUID)
    }

    // MARK: - Invalidation

    func invalidateAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        log.append(.info, "Cache invalidated", source: "cache")
    }

    // MARK: - Cache logic

    private func cached<T: Codable>(_ key: String, fetch: () async -> T) async -> T {
        let fileURL = cacheDir.appendingPathComponent("\(key).json")

        if let data = try? Data(contentsOf: fileURL),
           let entry = try? decoder.decode(CacheEntry<T>.self, from: data),
           Date().timeIntervalSince(entry.cachedAt) < ttl {
            log.append(.debug, "Cache hit: \(key)", source: "cache")
            return entry.data
        }

        log.append(.debug, "Cache miss: \(key)", source: "cache")
        let result = await fetch()

        let entry = CacheEntry(data: result, cachedAt: Date())
        if let data = try? encoder.encode(entry) {
            try? data.write(to: fileURL, options: .atomic)
        }

        return result
    }
}

private struct CacheEntry<T: Codable>: Codable {
    let data: T
    let cachedAt: Date
}
