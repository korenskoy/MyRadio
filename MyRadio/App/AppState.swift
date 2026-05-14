import SwiftUI
import AppKit
import RadioBrowserKit
import ServiceManagement

@Observable
final class AppState {
    // MARK: - Services
    let debugLog = DebugLog()
    let streamPlayer = StreamPlayer()
    let sleepTimer = SleepTimerService()
    let updateChecker = UpdateChecker()
    private let persistence = Persistence()
    private var cache: StationCache?
    private var nowPlayingController: NowPlayingController?

    // MARK: - Playback
    var currentStation: Station?
    var isPlaying: Bool { streamPlayer.isPlaying }
    var volume: Double {
        get { Double(streamPlayer.volume) }
        set {
            streamPlayer.volume = Float(newValue)
            persistPreferences()
        }
    }
    var nowPlayingTitle: String? { streamPlayer.nowPlayingTitle }
    var currentTrackArtwork: NSImage?

    // MARK: - Navigation
    var activeTab: TabKind = .discover {
        didSet { persistPreferences() }
    }
    var searchQuery: String = ""
    var showAddStation = false
    var showSleepTimer = false
    /// Bumped whenever the user invokes "Focus search" — SearchBar observes this
    /// to grab keyboard focus. Value itself is meaningless; only the change matters.
    var searchFocusRequest = UUID()

    // MARK: - Collections
    var stations: [Station] = []
    var favorites: [String] = []
    private var favoriteStationData: [String: Station] = [:]
    var history: [HistoryEntry] = []
    var customStations: [CustomStation] = []

    // MARK: - Tab-specific data
    var discoverTopVoted: [Station] = []
    var discoverPopular: [Station] = []
    var topVotedStations: [Station] = []
    var popularStations: [Station] = []
    var searchResults: [Station] = []
    var countryStations: [Station] = []
    var mapStations: [Station] = []
    var apiCountries: [NamedCount] = []

    // MARK: - Loading states
    var isLoadingTab = false

    // MARK: - Country selection
    var selectedCountryCode: String?

    // MARK: - Debug panel
    var logsVisible: Bool = false
    var activeDebugTab: DebugTab = .logs
    weak var devToolsNSWindow: NSWindow?

    // MARK: - Mini mode
    var isMiniMode: Bool = false

    // MARK: - Appearance
    var theme: AppTheme = .auto {
        didSet {
            persistPreferences()
            // Mirror to UserDefaults so the Settings scene (separate SwiftUI tree)
            // gets a cross-scene invalidation via @AppStorage.
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }
    var accent: AccentName = .system {
        didSet {
            persistPreferences()
            UserDefaults.standard.set(accent.rawValue, forKey: "appAccent")
        }
    }
    private(set) var systemColorEpoch: Int = 0

    // MARK: - General
    var language: AppLanguage = .system {
        didSet {
            persistPreferences()
            applyLanguageOverride()
        }
    }
    var launchAtLogin: Bool = false {
        didSet {
            persistPreferences()
            applyLaunchAtLogin()
        }
    }
    var restoreLastStation: Bool = true {
        didSet { persistPreferences() }
    }
    var confirmQuit: Bool = true {
        didSet { persistPreferences() }
    }
    /// UUID of the last station played — restored on next launch if
    /// `restoreLastStation` is on. Persisted via `play(...)`.
    private var lastStationUUID: String?

    private func persistPreferences() {
        let snapshot = Preferences(
            volume: Float(volume),
            activeTab: activeTab,
            theme: theme,
            accent: accent,
            language: language,
            launchAtLogin: launchAtLogin,
            restoreLastStation: restoreLastStation,
            confirmQuit: confirmQuit,
            lastStationUUID: lastStationUUID
        )
        Task { await persistence.savePreferences(snapshot) }
    }

    var applicationSupportURL: URL { persistence.directoryURL }

    func resetAllPreferences() {
        theme = .auto
        accent = .system
        streamPlayer.volume = 0.7
        activeTab = .discover
        language = .system
        launchAtLogin = false
        restoreLastStation = true
        confirmQuit = true
        Task { await persistence.resetPreferences() }
    }

    // MARK: - General side-effects

    /// Writes/clears the `AppleLanguages` override in standard UserDefaults.
    /// macOS picks up the change on the next process launch.
    private func applyLanguageOverride() {
        let key = "AppleLanguages"
        if let codes = language.appleLanguagesCodes {
            UserDefaults.standard.set(codes, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            debugLog.append(.warn, "Launch-at-login toggle failed: \(error.localizedDescription)", source: "app.general")
        }
    }

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
        favorites.reversed().compactMap { uuid in
            if let station = favoriteStationData[uuid] { return station }
            let allStations = stations + discoverTopVoted + discoverPopular
                + topVotedStations + popularStations
                + searchResults + countryStations + mapStations
            return allStations.first { $0.stationuuid == uuid }
        }
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains(station.stationuuid)
    }

    // MARK: - Init

    init() {
        streamPlayer.configure(log: debugLog)
        sleepTimer.onFire = { [weak self] in
            self?.stopPlayback()
            NotificationService.fireSleepTimerExpired()
        }
        nowPlayingController = NowPlayingController(state: self)

        NotificationCenter.default.addObserver(
            forName: NSColor.systemColorsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.systemColorEpoch += 1
        }
        debugLog.append(.info, "Application started · MyRadio v1.0.0", source: "app.boot")

        updateChecker.start()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let api = RadioBrowserAPI(log: self.debugLog)
            self.cache = StationCache(api: api, log: self.debugLog)
            if let prefs = await self.persistence.loadPreferences() {
                self.streamPlayer.volume = prefs.volume
                self.activeTab = prefs.activeTab
                if let theme    = prefs.theme    { self.theme    = theme }
                if let accent   = prefs.accent   { self.accent   = accent }
                if let language = prefs.language { self.language = language }
                if let launch   = prefs.launchAtLogin      { self.launchAtLogin      = launch }
                if let restore  = prefs.restoreLastStation { self.restoreLastStation = restore }
                if let confirm  = prefs.confirmQuit        { self.confirmQuit        = confirm }
                self.lastStationUUID = prefs.lastStationUUID
            }
            self.favorites = await self.persistence.loadFavorites()
            self.favoriteStationData = await self.persistence.loadFavoriteStations()
            self.history = await self.persistence.loadHistory()
            self.customStations = await self.persistence.loadCustomStations()

            self.debugLog.append(.info, "Loaded \(self.favorites.count) favorites, \(self.history.count) history entries, \(self.customStations.count) custom stations", source: "app.boot")

            await self.loadTabData(for: .discover)

            if self.restoreLastStation,
               let uuid = self.lastStationUUID,
               let station = self.station(for: uuid) {
                self.debugLog.append(.info, "Restoring last station: \(station.name)", source: "app.boot")
                self.currentStation = station
            }
        }
    }

    // MARK: - Actions

    func play(_ station: Station) {
        recordHistoryForCurrentStation()

        currentStation = station
        playStartTime = Date()
        lastStationUUID = station.stationuuid
        persistPreferences()

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

    func toggleMiniMode() {
        if isMiniMode {
            isMiniMode = false
            MiniWindowManager.shared.close()
            for window in NSApp.windows where window.contentView != nil && window.frame.width > AppLayout.miniWidth {
                window.makeKeyAndOrderFront(nil)
                break
            }
        } else {
            isMiniMode = true
            MiniWindowManager.shared.show(state: self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                for window in NSApp.windows where window.contentView != nil && window.isVisible {
                    if window is NSPanel { continue }
                    if window.frame.width > AppLayout.miniWidth {
                        window.orderOut(nil)
                    }
                }
            }
        }
    }

    func stopPlayback() {
        recordHistoryForCurrentStation()
        streamPlayer.stop()
        currentStation = nil
        playStartTime = nil
        sleepTimer.cancel()
    }

    func toggleFavorite(_ station: Station) {
        if favorites.contains(station.stationuuid) {
            favorites.removeAll { $0 == station.stationuuid }
            favoriteStationData.removeValue(forKey: station.stationuuid)
        } else {
            favorites.append(station.stationuuid)
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
            if topVotedStations.isEmpty {
                topVotedStations = await cache.topVoted(200)
            }

        case .popular:
            if popularStations.isEmpty {
                popularStations = await cache.topClicked(200)
            }

        case .search:
            guard !searchQuery.isEmpty else {
                searchResults = []
                return
            }
            searchResults = await cache.search(name: searchQuery)

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

    func reloadMapStations() async {
        cache?.invalidateGeo()
        mapStations = []
        await loadTabData(for: .map)
    }

    func reloadTopVoted() async {
        cache?.invalidateTopVoted()
        topVotedStations = []
        await loadTabData(for: .topVoted)
    }

    func reloadPopular() async {
        cache?.invalidatePopular()
        popularStations = []
        await loadTabData(for: .popular)
    }

    func reloadCountries() async {
        cache?.invalidateCountries()
        apiCountries = []
        await loadTabData(for: .countries)
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
        autoFavoriteCustom(station)
        Task {
            await persistence.saveCustomStations(customStations)
            await persistence.saveFavorites(favorites)
            await persistence.saveFavoriteStations(favoriteStationData)
        }
        debugLog.append(.info, "Added custom station: \(name)", source: "custom")
    }

    func removeCustomStation(id: UUID) {
        guard let custom = customStations.first(where: { $0.id == id }) else { return }
        customStations.removeAll { $0.id == id }
        let uuid = custom.id.uuidString
        favorites.removeAll { $0 == uuid }
        favoriteStationData.removeValue(forKey: uuid)
        Task {
            await persistence.saveCustomStations(customStations)
            await persistence.saveFavorites(favorites)
            await persistence.saveFavoriteStations(favoriteStationData)
        }
    }

    func importM3U(_ text: String) async {
        let parsed = M3UParser.parse(text)
        guard !parsed.isEmpty else {
            debugLog.append(.warn, "M3U import: no stations found", source: "custom")
            return
        }
        var matched = 0
        for custom in parsed {
            if let rbk = await cache?.stationsByURL(custom.url).first {
                if !favorites.contains(rbk.stationuuid) {
                    favorites.append(rbk.stationuuid)
                    favoriteStationData[rbk.stationuuid] = rbk
                }
                matched += 1
            }
        }
        await persistence.saveFavorites(favorites)
        await persistence.saveFavoriteStations(favoriteStationData)
        let skipped = parsed.count - matched
        debugLog.append(.info, "M3U import: \(matched) matched in RBK, \(skipped) not found (skipped)", source: "custom")
    }

    private func autoFavoriteCustom(_ custom: CustomStation) {
        let station = customStationAsStation(custom)
        guard !favorites.contains(station.stationuuid) else { return }
        favorites.append(station.stationuuid)
        favoriteStationData[station.stationuuid] = station
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

    // MARK: - Station lookup

    func station(for uuid: String) -> Station? {
        if let s = favoriteStationData[uuid] { return s }
        let all = stations + discoverTopVoted + discoverPopular
            + topVotedStations + popularStations
            + searchResults + countryStations + mapStations
        return all.first { $0.stationuuid == uuid }
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
