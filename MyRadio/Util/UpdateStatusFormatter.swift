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
        guard let date else { return "Not checked yet" }
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 30 { return "Last checked just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last checked \(formatter.localizedString(for: date, relativeTo: now))"
    }

    static func nextCheck(after lastCheckedAt: Date?,
                          interval: TimeInterval,
                          now: Date = Date()) -> String? {
        guard let lastCheckedAt else { return nil }
        let elapsed = now.timeIntervalSince(lastCheckedAt)
        let remaining = max(0, interval - elapsed)
        if remaining <= 0 { return "next check due" }
        return "next check in \(approximateDuration(remaining))"
    }

    /// Compact, human-rounded duration: "~5 min", "~2h", "~1 day".
    static func approximateDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "~1 min" }
        if minutes < 60 { return "~\(minutes) min" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "~\(hours)h" }
        let days = Int(seconds / 86_400)
        return days == 1 ? "~1 day" : "~\(days) days"
    }
}
