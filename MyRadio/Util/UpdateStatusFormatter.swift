//
//  UpdateStatusFormatter.swift
//  MyRadio
//
//  Pure formatters for the About → update card. `now` is injected so tests
//  stay deterministic without freezing wall-clock state.
//

import Foundation

enum UpdateStatusFormatter {
    static func lastChecked(at date: Date?, now: Date = Date()) -> String {
        guard let date else { return String(localized: "Not checked yet") }
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 30 { return String(localized: "Last checked just now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: now)
        return String(localized: "Last checked \(relative)")
    }

    static func nextCheck(after lastCheckedAt: Date?,
                          interval: TimeInterval,
                          now: Date = Date()) -> String? {
        guard let lastCheckedAt else { return nil }
        let elapsed = now.timeIntervalSince(lastCheckedAt)
        let remaining = max(0, interval - elapsed)
        if remaining <= 0 { return String(localized: "next check due") }
        let dur = approximateDuration(remaining)
        return String(localized: "next check in \(dur)")
    }

    /// Compact, human-rounded duration: "~5 min", "~2h", "~1 day".
    static func approximateDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return String(localized: "~1 min") }
        if minutes < 60 { return String(localized: "~\(minutes) min") }
        let hours = Int(seconds / 3600)
        if hours < 24 { return String(localized: "~\(hours)h") }
        let days = Int(seconds / 86_400)
        return days == 1
            ? String(localized: "~1 day")
            : String(localized: "~\(days) days")
    }
}
