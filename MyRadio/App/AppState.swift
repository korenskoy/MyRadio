import SwiftUI
import RadioBrowserKit

@Observable
final class AppState {
    // MARK: - Playback
    var currentStation: Station?
    var isPlaying: Bool = false
    var volume: Double = 0.65
    var nowPlayingTitle: String? = "Alice Coltrane — Journey in Satchidananda"

    // MARK: - Navigation
    var activeTab: TabKind = .discover
    var searchQuery: String = ""

    // MARK: - Collections (loaded from Persistence in Этапе 3)
    var stations: [Station] = MockData.stations
    var favorites: Set<String> = MockData.defaultFavorites
    var history: [HistoryEntry] = MockData.history

    // MARK: - Debug panel
    var logsVisible: Bool = true
    var activeDebugTab: DebugTab = .logs

    // MARK: - Appearance
    var theme: AppTheme = .auto
    var accent: AccentName = .green

    // MARK: - Computed

    var historyGroups: [HistoryGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: history) { entry in
            cal.startOfDay(for: entry.playedAt)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { HistoryGroup(day: $0.key, items: $0.value.sorted { $0.playedAt > $1.playedAt }) }
    }

    var favoriteStations: [Station] {
        stations.filter { favorites.contains($0.stationuuid) }
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains(station.stationuuid)
    }

    // MARK: - Actions

    func play(_ station: Station) {
        currentStation = station
        isPlaying = true
    }

    func togglePlayPause() {
        isPlaying.toggle()
    }

    func toggleFavorite(_ station: Station) {
        if favorites.contains(station.stationuuid) {
            favorites.remove(station.stationuuid)
        } else {
            favorites.insert(station.stationuuid)
        }
    }

    func appColors(systemDark: Bool) -> AppColors {
        AppColors.make(theme: theme, accent: accent, systemDark: systemDark)
    }

    init() {
        currentStation = MockData.stations.first
        isPlaying = true
    }
}
