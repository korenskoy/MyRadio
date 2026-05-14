//
//  UpdateChecker.swift
//  MyRadio
//
//  Polls the GitHub Releases atom feed and publishes an availableUpdate
//  when the latest published MARKETING_VERSION is newer than the running build.
//

import Foundation
import Combine
import os.log

@MainActor
final class UpdateChecker: ObservableObject {
    struct AvailableUpdate: Equatable {
        let version: String
        let url: URL
    }

    @Published private(set) var availableUpdate: AvailableUpdate?
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var isChecking: Bool = false
    @Published var autoCheckOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckOnLaunch, forKey: Self.autoCheckKey)
            applyAutoCheckPolicy()
        }
    }

    let checkInterval: TimeInterval = 24 * 60 * 60

    private static let autoCheckKey = "autoCheckUpdates"
    private static let log = Logger(subsystem: "ru.korenskoy.MyRadio", category: "UpdateChecker")
    private let feedURL = URL(string: "https://github.com/korenskoy/MyRadio/releases.atom")!
    private let session: URLSession
    private var timer: Timer?

    init(session: URLSession = .shared) {
        self.session = session
        let stored = UserDefaults.standard.object(forKey: Self.autoCheckKey) as? Bool
        self.autoCheckOnLaunch = stored ?? true
    }

    func start() {
        guard autoCheckOnLaunch else { return }
        Task { await checkNow() }
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkNow() async {
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            guard (200..<300).contains(http.statusCode) else {
                Self.log.error("Atom feed HTTP \(http.statusCode)")
                lastCheckedAt = Date()
                return
            }
            lastCheckedAt = Date()
            guard let latest = AtomFeedParser.parseLatestStable(data: data) else {
                Self.log.notice("No usable entry in atom feed")
                availableUpdate = nil
                return
            }
            let current = AppVersion.marketing
            if Self.compareSemver(latest.version, current) == .orderedDescending {
                Self.log.notice("Update available: \(latest.version, privacy: .public) > \(current, privacy: .public)")
                availableUpdate = AvailableUpdate(version: latest.version, url: latest.url)
            } else {
                availableUpdate = nil
            }
        } catch {
            Self.log.error("Atom feed fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyAutoCheckPolicy() {
        if autoCheckOnLaunch {
            if timer == nil { scheduleTimer() }
        } else {
            stop()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.checkNow() }
        }
    }

    /// Numeric component-wise comparison: "1.2" < "1.2.1" < "1.10".
    nonisolated static func compareSemver(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    /// Reject prerelease tags (beta/alpha/rc/preview/dev/nightly).
    /// Letter-boundary lookarounds so "rc1" and "-beta" match while
    /// "developer", "march", "preview-er-wrong-context" do not.
    nonisolated static func isPrerelease(_ raw: String) -> Bool {
        let pattern = #"(?<![a-z])(alpha|beta|rc|preview|dev|nightly)(?![a-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        let range = NSRange(raw.startIndex..., in: raw)
        return regex.firstMatch(in: raw, range: range) != nil
    }
}
