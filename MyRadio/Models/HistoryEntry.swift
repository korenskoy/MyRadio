import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let stationUUID: String
    let stationName: String
    let playedAt: Date
    var duration: TimeInterval  // seconds

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var timeFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: playedAt)
    }
}

struct HistoryGroup: Identifiable {
    let day: Date
    var items: [HistoryEntry]

    var id: Date { day }

    var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return String(localized: "Today") }
        if cal.isDateInYesterday(day) { return String(localized: "Yesterday") }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: day)
    }
}
