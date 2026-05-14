//
//  DurationLabel.swift
//  MyRadio
//
//  Locale-aware narrow duration labels used by the sleep-timer ring, the
//  slider tags ("5m" / "1h"), the player's sleep-countdown chip, and any
//  other place that previously hardcoded `"\(h)h \(m)m"` with Latin units.
//
//  Why narrow: matches the existing compact visual ("5m", "1h 30m") but
//  `Duration.UnitsFormatStyle` resolves both the digits AND the unit
//  abbreviations through `Locale.current`. In English that's still "5m"; in
//  Persian it becomes "۵ د" (Persian digit + Persian-shorthand for دقیقه).
//

import Foundation

enum DurationLabel {
    /// Narrow label for a whole-minute duration: "5m" / "1h" / "1h 30m"
    /// (or the same with the localized digits + unit abbreviations).
    static func narrow(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        let units: Set<Duration.UnitsFormatStyle.Unit>
        if hours == 0       { units = [.minutes] }
        else if mins == 0   { units = [.hours] }
        else                { units = [.hours, .minutes] }
        return Duration.seconds(minutes * 60)
            .formatted(.units(allowed: units, width: .narrow))
    }

    /// Narrow label for a seconds-resolution remaining time: "45s" / "1m 30s" /
    /// "8h" / "1h 23m". Picks the coarsest set of units that still surfaces a
    /// non-zero value, matching the original sleep-timer behaviour.
    static func narrow(seconds totalSecondsRaw: TimeInterval) -> String {
        let totalSeconds = Int(max(0, totalSecondsRaw))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60

        let units: Set<Duration.UnitsFormatStyle.Unit>
        if mins >= 60 {
            units = secs == 0 && mins % 60 == 0 ? [.hours] : [.hours, .minutes]
        } else if mins > 0 {
            // Past 90 s of remaining time the seconds tick is just noise; once
            // we're under a minute and a half we surface mm:ss so the user
            // sees the final countdown.
            units = totalSecondsRaw > 90 ? [.minutes] : [.minutes, .seconds]
        } else {
            units = [.seconds]
        }
        return Duration.seconds(totalSeconds)
            .formatted(.units(allowed: units, width: .narrow))
    }
}
