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
        await api.stationsByURL(url) ?? []
    }

    func stationsWithGeo() async -> [Station] {
        await cached("geo-all") { await self.api.stationsWithGeo() }
    }

    // MARK: - Metadata

    func tags(limit: Int = 200) async -> [NamedCount] {
        await cached("tags-\(limit)") { await self.api.tags(limit: limit) }
    }

    func countries() async -> [NamedCount] {
        await cached("countries-all") { await self.api.countries() }
    }

    /// Not cached — small, dev-only, and should reflect live mirror health.
    func servers() async -> [StreamingServerMirror] {
        await api.servers() ?? []
    }

    func invalidateCountries() {
        invalidate(prefix: "countries-")
        log.append(.info, "Countries cache invalidated", source: "cache")
    }

    // MARK: - Pass-through

    func registerClick(stationUUID: String) async {
        await api.registerClick(stationUUID: stationUUID)
    }

    func registerVote(stationUUID: String) async {
        await api.registerVote(stationUUID: stationUUID)
    }

    // MARK: - Invalidation

    func invalidateTopVoted() {
        // Both the 50- (discover) and 200-count files share this prefix; a
        // single count-specific delete would leave the quick-screen list stale.
        invalidate(prefix: "topVoted-")
    }

    func invalidatePopular() {
        invalidate(prefix: "topClicked-")
    }

    func invalidateGeo() {
        invalidate(prefix: "geo-")
        log.append(.info, "Geo cache invalidated", source: "cache")
    }

    /// Removes every cache file whose name starts with `prefix` (e.g. all
    /// `topVoted-*` regardless of count).
    private func invalidate(prefix: String) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fm.removeItem(at: file)
        }
    }

    func invalidateAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        log.append(.info, "Cache invalidated", source: "cache")
    }

    // MARK: - Cache logic

    /// `fetch` returns `nil` to signal a network/decoding failure (as opposed to
    /// a genuinely empty result). On failure we never overwrite the cache; we
    /// serve stale data if present, otherwise return empty — so one timeout at
    /// cold start can't pin an empty list for the whole TTL.
    private func cached<Element: Codable>(_ key: String, fetch: () async -> [Element]?) async -> [Element] {
        let fileURL = cacheDir.appendingPathComponent("\(key).json")
        let cachedEntry: CacheEntry<[Element]>? = (try? Data(contentsOf: fileURL))
            .flatMap { try? decoder.decode(CacheEntry<[Element]>.self, from: $0) }

        if let entry = cachedEntry, Date().timeIntervalSince(entry.cachedAt) < ttl {
            log.append(.debug, "Cache hit: \(key)", source: "cache")
            return entry.data
        }

        log.append(.debug, "Cache miss: \(key)", source: "cache")
        guard let result = await fetch() else {
            if let entry = cachedEntry {
                let age = Int(Date().timeIntervalSince(entry.cachedAt))
                log.append(.warn, "Fetch failed for \(key); serving stale cache (\(age)s old)", source: "cache")
                return entry.data
            }
            log.append(.warn, "Fetch failed for \(key); no cache to fall back on", source: "cache")
            return []
        }

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
