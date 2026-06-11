import Foundation
import RadioBrowserKit

actor RadioBrowserAPI {
    private let client: RadioBrowser
    private let log: DebugLog
    private var clickTimestamps: [String: Date] = [:]
    private var voteTimestamps: [String: Date] = [:]

    private let clickCooldown: TimeInterval = 600   // 10 minutes
    private let voteCooldown: TimeInterval = 86400   // 24 hours

    init(log: DebugLog) {
        self.client = RadioBrowser()
        self.log = log

        RadioBrowserKit.configuration = RadioBrowserConfig(
            logging: LogConfiguration(
                enabled: [.network, .mirrors, .decode, .api, .general],
                minLevel: .debug,
                redactPII: false,
                emitCURL: true
            )
        )
        RadioBrowserKit.setLogger(RBKLogBridge(log))

        log.append(.info, "RadioBrowser client initialized", source: "rb.client")
    }

    // MARK: - Stations

    /// All fetch methods return `nil` on failure (transport/decoding/server)
    /// and a (possibly empty) array on success. This lets the cache layer tell a
    /// genuine empty result apart from an error and avoid caching failures.

    func topVoted(_ count: Int = 50) async -> [Station]? {
        await fetch("topVote(\(count))") {
            try await client.topVote(count)
        }
    }

    func topClicked(_ count: Int = 50) async -> [Station]? {
        await fetch("topClick(\(count))") {
            try await client.topClick(count)
        }
    }

    func search(name: String, limit: Int = 100) async -> [Station]? {
        var q = StationSearchQuery()
        q.name = name
        q.limit = limit
        q.order = .votes
        q.reverse = true
        q.hidebroken = true
        return await fetch("search(name: \(name))") {
            try await client.search(q)
        }
    }

    func stationsByTag(_ tag: String, limit: Int = 100) async -> [Station]? {
        await fetch("stationsByTag(\(tag))") {
            try await client.stationsByTag(tag, exact: true, order: .votes, reverse: true, limit: limit)
        }
    }

    func stationsByCountryCode(_ code: String, limit: Int = 100) async -> [Station]? {
        await fetch("stationsByCountryCode(\(code))") {
            try await client.stationsByCountryCode(code, order: .votes, reverse: true, limit: limit)
        }
    }

    func stationsByCountry(_ name: String, limit: Int = 100) async -> [Station]? {
        await fetch("stationsByCountry(\(name))") {
            try await client.stationsByCountry(name, exact: true, order: .votes, reverse: true, limit: limit)
        }
    }

    func stationsByURL(_ url: String) async -> [Station]? {
        await fetch("stationsByURL(\(url))") {
            try await client.stationsByURL(url)
        }
    }

    func stationsWithGeo() async -> [Station]? {
        let pageSize = 1_000
        var all: [Station] = []
        var offset = 0
        repeat {
            var q = StationSearchQuery()
            q.hasGeoInfo = true
            q.hidebroken = true
            q.limit  = pageSize
            q.offset = offset
            // A failed page must NOT be treated as "end of data" — that would
            // cache a truncated list as if it were complete.
            let pageResult = await fetch("stationsWithGeo[\(offset)]") {
                try await self.client.search(q)
            }
            guard let page = pageResult else { return nil }
            all.append(contentsOf: page)
            log.append(.info, "stationsWithGeo: \(all.count) loaded", source: "rb.client")
            if page.count < pageSize { break }
            offset += pageSize
        } while true
        return all
    }

    // MARK: - Metadata

    func tags(limit: Int = 200) async -> [NamedCount]? {
        let result: [NamedCount]? = await fetch("tags") {
            try await client.tags(limit: limit)
        }
        return result?.sorted { $0.stationcount > $1.stationcount }
    }

    /// Real Radio Browser mirror servers (for the DevTools Servers tab).
    func servers() async -> [StreamingServerMirror]? {
        await fetch("servers") {
            try await client.servers()
        }
    }

    func countries() async -> [NamedCount]? {
        let pageSize = 100
        var all: [NamedCount] = []
        var offset = 0
        repeat {
            let pageResult: [NamedCount]? = await fetch("countries[\(offset)]") {
                try await self.client.countries(offset: offset, limit: pageSize)
            }
            guard let page = pageResult else { return nil }
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        } while true
        return all.sorted { $0.stationcount > $1.stationcount }
    }

    // MARK: - Interactions (throttled)

    func registerClick(stationUUID: String) async {
        if let last = clickTimestamps[stationUUID],
           Date().timeIntervalSince(last) < clickCooldown {
            log.append(.debug, "Click throttled for \(stationUUID)", source: "rb.throttle")
            return
        }
        do {
            let resp = try await client.click(stationUUID: stationUUID)
            clickTimestamps[stationUUID] = Date()
            // Drop entries past their cooldown so the dictionary doesn't grow
            // without bound over a long session.
            let cutoff = Date().addingTimeInterval(-clickCooldown)
            clickTimestamps = clickTimestamps.filter { $0.value > cutoff }
            log.append(.info, "Click registered for \(stationUUID) → \(resp.url)", source: "rb.client")
        } catch {
            handleError(error, context: "click(\(stationUUID))")
        }
    }

    func registerVote(stationUUID: String) async {
        if let last = voteTimestamps[stationUUID],
           Date().timeIntervalSince(last) < voteCooldown {
            log.append(.debug, "Vote throttled for \(stationUUID)", source: "rb.throttle")
            return
        }
        do {
            let resp = try await client.vote(stationUUID: stationUUID)
            voteTimestamps[stationUUID] = Date()
            let cutoff = Date().addingTimeInterval(-voteCooldown)
            voteTimestamps = voteTimestamps.filter { $0.value > cutoff }
            log.append(.info, "Vote registered for \(stationUUID) → \(resp.votes) votes", source: "rb.client")
        } catch {
            handleError(error, context: "vote(\(stationUUID))")
        }
    }

    // MARK: - Helpers

    private func fetch<T>(_ label: String, _ block: () async throws -> T) async -> T? {
        do {
            let result = try await block()
            if let arr = result as? [Any] {
                log.append(.info, "\(label) → \(arr.count) results", source: "rb.client")
            }
            return result
        } catch {
            handleError(error, context: label)
            return nil
        }
    }

    private func handleError(_ error: Error, context: String) {
        let level: LogEntry.Level
        let message: String

        if let rbError = error as? RadioBrowserError {
            switch rbError {
            case .rateLimited:
                level = .warn
                message = "\(context): rate limited"
            case .transport(let inner):
                level = .error
                message = "\(context): transport error — \(inner.localizedDescription)"
            case .serverUnavailable:
                level = .error
                message = "\(context): server unavailable"
            case .decoding(let inner):
                level = .warn
                message = "\(context): decoding error — \(inner.localizedDescription)"
            case .notFound:
                level = .warn
                message = "\(context): not found"
            case .apiResponse(let msg):
                level = .warn
                message = "\(context): API error — \(msg)"
            case .invalidRequest(let msg):
                level = .error
                message = "\(context): invalid request — \(msg)"
            }
        } else {
            level = .error
            message = "\(context): \(error.localizedDescription)"
        }

        log.append(level, message, source: "rb.client")
    }
}
