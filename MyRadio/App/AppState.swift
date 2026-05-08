import SwiftUI
import AppKit
import RadioBrowserKit

@Observable
final class AppState {
    // MARK: - Services
    let debugLog = DebugLog()
    let streamPlayer = StreamPlayer()
    private let persistence = Persistence()
    private var cache: StationCache?

    // MARK: - Playback
    var currentStation: Station?
    var isPlaying: Bool { streamPlayer.isPlaying }
    var volume: Double {
        get { Double(streamPlayer.volume) }
        set { streamPlayer.volume = Float(newValue) }
    }
    var nowPlayingTitle: String? { streamPlayer.nowPlayingTitle }

    // MARK: - Navigation
    var activeTab: TabKind = .discover
    var searchQuery: String = ""
    var showAddStation = false

    // MARK: - Collections
    var stations: [Station] = []
    var favorites: Set<String> = []
    private var favoriteStationData: [String: Station] = [:]
    var history: [HistoryEntry] = []
    var customStations: [CustomStation] = []

    // MARK: - Tab-specific data
    var discoverTopVoted: [Station] = []
    var discoverPopular: [Station] = []
    var topVotedStations: [Station] = []
    var popularStations: [Station] = []
    var searchResults: [Station] = []
    var tagStations: [Station] = []
    var countryStations: [Station] = []
    var mapStations: [Station] = []
    var apiTags: [NamedCount] = []
    var apiCountries: [NamedCount] = []

    // MARK: - Loading states
    var isLoadingTab = false

    // MARK: - Tag/Country selection
    var selectedTag: String?
    var selectedCountryCode: String?

    // MARK: - Debug panel
    var logsVisible: Bool = false
    var activeDebugTab: DebugTab = .logs
    weak var devToolsNSWindow: NSWindow?

    // MARK: - Mini mode
    var isMiniMode: Bool = false

    // MARK: - Appearance
    var theme: AppTheme = .auto
    var accent: AccentName = .green

    // MARK: - History tracking
    private var playStartTime: Date?

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
        favorites.compactMap { uuid in
            if let station = favoriteStationData[uuid] { return station }
            let allStations = stations + discoverTopVoted + discoverPopular
                + topVotedStations + popularStations
                + searchResults + tagStations + countryStations + mapStations
            return allStations.first { $0.stationuuid == uuid }
        }
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains(station.stationuuid)
    }

    // MARK: - Init

    init() {
        streamPlayer.configure(log: debugLog)
        debugLog.append(.info, "Application started · MyRadio v1.0.0", source: "app.boot")

        Task { @MainActor [weak self] in
            guard let self else { return }
            let api = RadioBrowserAPI(log: self.debugLog)
            self.cache = StationCache(api: api, log: self.debugLog)
            self.favorites = await self.persistence.loadFavorites()
            self.favoriteStationData = await self.persistence.loadFavoriteStations()
            self.history = await self.persistence.loadHistory()
            self.customStations = await self.persistence.loadCustomStations()

            self.debugLog.append(.info, "Loaded \(self.favorites.count) favorites, \(self.history.count) history entries, \(self.customStations.count) custom stations", source: "app.boot")

            await self.loadTabData(for: .discover)
        }
    }

    // MARK: - Actions

    func play(_ station: Station) {
        recordHistoryForCurrentStation()

        currentStation = station
        playStartTime = Date()

        guard let url = URL(string: station.urlResolved ?? station.url) else {
            debugLog.append(.error, "Invalid stream URL for \(station.name)", source: "audio.player")
            return
        }

        streamPlayer.play(url: url)

        Task {
            await cache?.registerClick(stationUUID: station.stationuuid)
        }
    }

    func togglePlayPause() {
        streamPlayer.togglePlayPause()
    }

    func stopPlayback() {
        recordHistoryForCurrentStation()
        streamPlayer.stop()
        currentStation = nil
        playStartTime = nil
    }

    func toggleFavorite(_ station: Station) {
        if favorites.contains(station.stationuuid) {
            favorites.remove(station.stationuuid)
            favoriteStationData.removeValue(forKey: station.stationuuid)
        } else {
            favorites.insert(station.stationuuid)
            favoriteStationData[station.stationuuid] = station
        }
        Task {
            await persistence.saveFavorites(favorites)
            await persistence.saveFavoriteStations(favoriteStationData)
        }
    }

    func vote(for station: Station) {
        Task { await cache?.registerVote(stationUUID: station.stationuuid) }
    }

    func appColors(systemDark: Bool) -> AppColors {
        AppColors.make(theme: theme, accent: accent, systemDark: systemDark)
    }

    // MARK: - Tab data loading

    func loadTabData(for tab: TabKind) async {
        guard let cache else { return }
        isLoadingTab = true
        defer { isLoadingTab = false }

        switch tab {
        case .discover:
            async let top = cache.topVoted(50)
            async let pop = cache.topClicked(50)
            discoverTopVoted = await top
            discoverPopular = await pop
            if stations.isEmpty {
                stations = discoverTopVoted
            }

        case .topVoted:
            topVotedStations = await cache.topVoted(200)

        case .popular:
            popularStations = await cache.topClicked(200)

        case .search:
            guard !searchQuery.isEmpty else {
                searchResults = []
                return
            }
            searchResults = await cache.search(name: searchQuery)

        case .tags:
            if apiTags.isEmpty {
                apiTags = await cache.tags()
            }

        case .countries:
            if apiCountries.isEmpty {
                apiCountries = await cache.countries()
            }

        case .map:
            if mapStations.isEmpty {
                mapStations = await cache.stationsWithGeo()
            }

        case .favorites, .history:
            break
        }
    }

    func loadStationsForTag(_ tag: String) async {
        guard let cache else { return }
        selectedTag = tag
        tagStations = await cache.stationsByTag(tag)
    }

    func loadStationsForCountry(_ name: String) async {
        guard let cache else { return }
        selectedCountryCode = name
        countryStations = await cache.stationsByCountry(name)
    }

    func performSearch() async {
        guard let cache, !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        isLoadingTab = true
        searchResults = await cache.search(name: searchQuery)
        isLoadingTab = false
    }

    // MARK: - Custom stations

    func addCustomStation(
        name: String,
        url: String,
        country: String? = nil,
        language: String? = nil,
        tags: String? = nil,
        bitrate: Int? = nil
    ) {
        let station = CustomStation(
            id: UUID(),
            name: name,
            url: url,
            country: country,
            language: language,
            tags: tags,
            bitrate: bitrate,
            addedAt: Date()
        )
        customStations.append(station)
        Task { await persistence.saveCustomStations(customStations) }
        debugLog.append(.info, "Added custom station: \(name)", source: "custom")
    }

    func removeCustomStation(id: UUID) {
        customStations.removeAll { $0.id == id }
        Task { await persistence.saveCustomStations(customStations) }
    }

    func importM3U(_ text: String) {
        let parsed = M3UParser.parse(text)
        guard !parsed.isEmpty else {
            debugLog.append(.warn, "M3U import: no stations found", source: "custom")
            return
        }
        customStations.append(contentsOf: parsed)
        Task { await persistence.saveCustomStations(customStations) }
        debugLog.append(.info, "Imported \(parsed.count) stations from M3U", source: "custom")
    }

    func customStationAsStation(_ custom: CustomStation) -> Station {
        var dict: [String: Any] = [
            "stationuuid": custom.id.uuidString,
            "name": custom.name,
            "url": custom.url,
        ]
        if let v = custom.tags    { dict["tags"] = v }
        if let v = custom.language { dict["language"] = v }
        if let v = custom.bitrate  { dict["bitrate"] = v }

        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(Station.self, from: data)
    }

    // MARK: - History management

    private func recordHistoryForCurrentStation() {
        guard let station = currentStation,
              let start = playStartTime else { return }

        let duration = Date().timeIntervalSince(start)
        guard duration > 10 else { return }

        let entry = HistoryEntry(
            id: UUID(),
            stationUUID: station.stationuuid,
            stationName: station.name,
            playedAt: start,
            duration: duration
        )
        history.insert(entry, at: 0)

        let maxHistory = 500
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }

        Task { await persistence.saveHistory(history) }
    }
}
