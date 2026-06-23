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
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
        }
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
    /// Real Radio Browser mirror servers — loaded on demand for the DevTools Servers tab.
    var servers: [StreamingServerMirror] = []

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
            guard !isHydrating else { return }
            persistPreferences()
            // Mirror to UserDefaults so the Settings scene (separate SwiftUI tree)
            // gets a cross-scene invalidation via @AppStorage.
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }
    var accent: AccentName = .system {
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
            UserDefaults.standard.set(accent.rawValue, forKey: "appAccent")
        }
    }
    private(set) var systemColorEpoch: Int = 0

    // MARK: - General
    var language: AppLanguage = .system {
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
            applyLanguageOverride()
        }
    }
    var launchAtLogin: Bool = false {
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
            applyLaunchAtLogin()
        }
    }
    var restoreLastStation: Bool = true {
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
        }
    }
    var confirmQuit: Bool = true {
        didSet {
            guard !isHydrating else { return }
            persistPreferences()
        }
    }
    /// UUID of the last station played — restored on next launch if
    /// `restoreLastStation` is on. Persisted via `play(...)`.
    private var lastStationUUID: String?

    // MARK: - Persistence guards
    /// True only while the init task is copying loaded values into properties.
    /// Suppresses the `didSet` persistence side-effects so launch doesn't write
    /// partial/redundant snapshots (and doesn't re-apply language/login overrides).
    private var isHydrating = false
    /// True once every collection has been loaded from disk. Until then,
    /// favorites/history/custom writes are blocked so an early user action can't
    /// overwrite the on-disk data with an empty in-memory array.
    private var isHydrated = false

    /// Per-file write generations. Handed to `Persistence.save` so a slower,
    /// older write can't land after a newer one and resurrect stale state.
    private var favGen = 0
    private var historyGen = 0
    private var customGen = 0
    private var prefsGen = 0
    /// Coalesces preference writes (e.g. the volume slider firing dozens of
    /// times a second) into a single debounced save.
    private var prefsSaveTask: Task<Void, Never>?

    private func currentPreferencesSnapshot() -> Preferences {
        Preferences(
            volume: Float(volume),
            activeTab: activeTab,
            theme: theme,
            accent: accent,
            language: language,
            launchAtLogin: launchAtLogin,
            restoreLastStation: restoreLastStation,
            confirmQuit: confirmQuit,
            lastStationUUID: lastStationUUID,
            wasPlaying: isPlaying
        )
    }

    private func persistPreferences() {
        guard !isHydrating else { return }
        prefsGen += 1
        let gen = prefsGen
        let snapshot = currentPreferencesSnapshot()
        prefsSaveTask?.cancel()
        prefsSaveTask = Task { [persistence] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await persistence.savePreferences(snapshot, generation: gen)
        }
    }

    // MARK: - Persistence helpers (ordered, hydration-guarded)

    private func saveFavoritesToDisk() {
        guard isHydrated else { return }
        favGen += 1
        let gen = favGen
        let favs = favorites
        let data = favoriteStationData
        Task { [persistence] in
            await persistence.saveFavorites(favs, generation: gen)
            await persistence.saveFavoriteStations(data, generation: gen)
        }
    }

    private func saveHistoryToDisk() {
        guard isHydrated else { return }
        historyGen += 1
        let gen = historyGen
        let snapshot = history
        Task { [persistence] in
            await persistence.saveHistory(snapshot, generation: gen)
        }
    }

    private func saveCustomStationsToDisk() {
        guard isHydrated else { return }
        customGen += 1
        let gen = customGen
        let snapshot = customStations
        Task { [persistence] in
            await persistence.saveCustomStations(snapshot, generation: gen)
        }
    }

    /// Records the in-flight listening session and flushes history to disk
    /// SYNCHRONOUSLY. Called from `applicationShouldTerminate` so a long session
    /// isn't lost on quit (the async writers never get a chance to run).
    func flushOnTerminate() {
        recordHistoryForCurrentStation()
        persistence.saveHistorySync(history)
        // Also flush preferences synchronously: the debounced async writer won't
        // run once we return terminateNow, so a last-second volume/tab change
        // would otherwise be dropped.
        if !isHydrating {
            prefsSaveTask?.cancel()
            persistence.savePreferencesSync(currentPreferencesSnapshot())
        }
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

    /// Writes/clears the `AppleLanguages` and `AppleLocale` overrides in
    /// standard UserDefaults. macOS picks both up on the next process launch.
    ///
    /// Why both: `AppleLanguages` controls which `.lproj` Bundle resolves and
    /// therefore which strings appear; `AppleLocale` controls `Locale.current`,
    /// which drives number/date formatting. Without `AppleLocale`, a user with
    /// system region = Russia who picks Persian gets Persian strings but
    /// Latin-script digits (because `Locale.current` ends up as `fa_RU` whose
    /// numbering system stays `latn`). Pinning both keeps `42` rendered as
    /// `۴۲` everywhere we run `Int.formatted()`.
    private func applyLanguageOverride() {
        let langKey = "AppleLanguages"
        let regionKey = "AppleLocale"
        if let codes = language.appleLanguagesCodes {
            UserDefaults.standard.set(codes, forKey: langKey)
            UserDefaults.standard.set(codes.first, forKey: regionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: langKey)
            UserDefaults.standard.removeObject(forKey: regionKey)
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
    /// When the current station started — used as the history entry's `playedAt`.
    private var sessionStartTime: Date?
    /// Start of the current *unpaused* segment, or nil while paused.
    private var segmentStartTime: Date?
    /// Active (unpaused) listening time banked from completed segments.
    private var accumulatedPlayTime: TimeInterval = 0

    // MARK: - Computed

    var historyGroups: [HistoryGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: history) { entry in
            cal.startOfDay(for: entry.playedAt)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { HistoryGroup(day: $0.key, items: $0.value.sorted { $0.playedAt > $1.playedAt }) }
    }

    /// Every station currently held in memory across all tab lists. Concatenated
    /// once (not per-lookup) by callers that need to resolve a UUID.
    private var allLoadedStations: [Station] {
        stations + discoverTopVoted + discoverPopular
            + topVotedStations + popularStations
            + searchResults + countryStations + mapStations
    }

    var favoriteStations: [Station] {
        // Resolve through a single lookup table instead of rebuilding (and
        // re-scanning) the concatenation of all lists for every favorite.
        var lookup = favoriteStationData
        if favorites.contains(where: { lookup[$0] == nil }) {
            for station in allLoadedStations where lookup[station.stationuuid] == nil {
                lookup[station.stationuuid] = station
            }
        }
        return favorites.reversed().compactMap { lookup[$0] }
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
        debugLog.append(.info, "Application started · MyRadio v\(AppVersion.displayString)", source: "app.boot")

        updateChecker.start()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.persistence.setErrorLogger { [weak log = self.debugLog] message in
                log?.append(.error, message, source: "persistence")
            }

            let api = RadioBrowserAPI(log: self.debugLog)
            self.cache = StationCache(api: api, log: self.debugLog)

            self.isHydrating = true
            var resumePlayback = false
            do {
                if let prefs = try await self.persistence.loadPreferences() {
                    self.streamPlayer.volume = prefs.volume
                    self.activeTab = prefs.activeTab
                    if let theme    = prefs.theme    { self.theme    = theme }
                    if let accent   = prefs.accent   { self.accent   = accent }
                    if let language = prefs.language { self.language = language }
                    if let launch   = prefs.launchAtLogin      { self.launchAtLogin      = launch }
                    if let restore  = prefs.restoreLastStation { self.restoreLastStation = restore }
                    if let confirm  = prefs.confirmQuit        { self.confirmQuit        = confirm }
                    self.lastStationUUID = prefs.lastStationUUID
                    resumePlayback = prefs.wasPlaying ?? false
                }
            } catch {
                self.debugLog.append(.error, "Preferences load failed (archived, using defaults): \(error.localizedDescription)", source: "app.boot")
            }
            self.isHydrating = false

            // Load collections. On corruption the file is archived and the throw
            // leaves the in-memory state untouched — never overwritten with empty.
            do { self.favorites = try await self.persistence.loadFavorites() }
            catch { self.debugLog.append(.error, "Favorites load failed (archived): \(error.localizedDescription)", source: "app.boot") }
            do { self.favoriteStationData = try await self.persistence.loadFavoriteStations() }
            catch { self.debugLog.append(.error, "Favorite stations load failed (archived): \(error.localizedDescription)", source: "app.boot") }
            do { self.history = try await self.persistence.loadHistory() }
            catch { self.debugLog.append(.error, "History load failed (archived): \(error.localizedDescription)", source: "app.boot") }
            do { self.customStations = try await self.persistence.loadCustomStations() }
            catch { self.debugLog.append(.error, "Custom stations load failed (archived): \(error.localizedDescription)", source: "app.boot") }

            self.isHydrated = true

            self.debugLog.append(.info, "Loaded \(self.favorites.count) favorites, \(self.history.count) history entries, \(self.customStations.count) custom stations", source: "app.boot")

            await self.loadTabData(for: .discover)

            if self.restoreLastStation,
               let uuid = self.lastStationUUID,
               let station = self.station(for: uuid) {
                if resumePlayback {
                    self.debugLog.append(.info, "Resuming last station: \(station.name)", source: "app.boot")
                    self.play(station)
                } else {
                    self.debugLog.append(.info, "Restoring last station: \(station.name)", source: "app.boot")
                    self.currentStation = station
                }
            }
        }
    }

    // MARK: - Actions

    func play(_ station: Station) {
        // Validate the URL BEFORE mutating any state — otherwise an unplayable
        // station would still become `currentStation`/`lastStationUUID` (shown in
        // the UI and restored on next launch) while the old stream keeps playing.
        guard let url = URL(string: station.urlResolved ?? station.url) else {
            debugLog.append(.error, "Invalid stream URL for \(station.name)", source: "audio.player")
            return
        }

        recordHistoryForCurrentStation()

        currentStation = station
        sessionStartTime = Date()
        segmentStartTime = Date()
        accumulatedPlayTime = 0
        lastStationUUID = station.stationuuid
        persistPreferences()

        streamPlayer.play(url: url)

        Task {
            await cache?.registerClick(stationUUID: station.stationuuid)
        }
    }

    /// Live radio has no meaningful pause: "stop" tears the stream down (frees the
    /// connection, never resumes stale buffered audio), but keeps `currentStation`
    /// so the next tap reconnects to the live edge. When nothing is loaded yet
    /// (e.g. a station restored on launch but not auto-played), it starts playback.
    func togglePlayPause() {
        if streamPlayer.isLoaded {
            recordHistoryForCurrentStation()
            streamPlayer.stop()
            sessionStartTime = nil
            segmentStartTime = nil
            accumulatedPlayTime = 0
            persistPreferences()   // wasPlaying = false now
        } else if let station = currentStation {
            play(station)
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                // A second quick toggle may have exited mini mode already; hiding
                // the main window now would leave the app with no visible window.
                guard let self, self.isMiniMode else { return }
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
        sessionStartTime = nil
        segmentStartTime = nil
        accumulatedPlayTime = 0
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
        saveFavoritesToDisk()
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

    func loadServers() async {
        guard let cache else { return }
        servers = await cache.servers()
    }

    func loadStationsForCountry(_ name: String) async {
        guard let cache else { return }
        selectedCountryCode = name
        let result = await cache.stationsByCountry(name)
        // A newer country selection may have superseded this one mid-flight —
        // don't paint country A's stations while the user is now on country B.
        guard selectedCountryCode == name else { return }
        countryStations = result
    }

    func performSearch() async {
        guard let cache else { searchResults = []; return }
        let query = searchQuery
        guard !query.isEmpty else {
            searchResults = []
            isLoadingTab = false
            return
        }
        isLoadingTab = true
        let results = await cache.search(name: query)
        // Drop a response that arrived after the user kept typing.
        guard query == searchQuery else { return }
        searchResults = results
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
        saveCustomStationsToDisk()
        saveFavoritesToDisk()
        debugLog.append(.info, "Added custom station: \(name)", source: "custom")
    }

    func removeCustomStation(id: UUID) {
        guard let custom = customStations.first(where: { $0.id == id }) else { return }
        customStations.removeAll { $0.id == id }
        let uuid = custom.id.uuidString
        favorites.removeAll { $0 == uuid }
        favoriteStationData.removeValue(forKey: uuid)
        saveCustomStationsToDisk()
        saveFavoritesToDisk()
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
        saveFavoritesToDisk()
        let skipped = parsed.count - matched
        debugLog.append(.info, "M3U import: \(matched) matched in RBK, \(skipped) not found (skipped)", source: "custom")
    }

    private func autoFavoriteCustom(_ custom: CustomStation) {
        guard let station = customStationAsStation(custom) else { return }
        guard !favorites.contains(station.stationuuid) else { return }
        favorites.append(station.stationuuid)
        favoriteStationData[station.stationuuid] = station
    }

    /// Builds a `Station` from a user-defined custom station. Returns nil (and
    /// logs) instead of trapping if RadioBrowserKit's model ever gains a new
    /// required field that this dictionary doesn't supply.
    func customStationAsStation(_ custom: CustomStation) -> Station? {
        var dict: [String: Any] = [
            "stationuuid": custom.id.uuidString,
            "name": custom.name,
            "url": custom.url,
        ]
        if let v = custom.tags    { dict["tags"] = v }
        if let v = custom.language { dict["language"] = v }
        if let v = custom.bitrate  { dict["bitrate"] = v }

        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Station.self, from: data)
        } catch {
            debugLog.append(.error, "Failed to build station from custom '\(custom.name)': \(error.localizedDescription)", source: "custom")
            return nil
        }
    }

    // MARK: - Station lookup

    func station(for uuid: String) -> Station? {
        if let s = favoriteStationData[uuid] { return s }
        return allLoadedStations.first { $0.stationuuid == uuid }
    }

    // MARK: - History management

    func clearHistory() {
        history = []
        saveHistoryToDisk()
    }

    private func recordHistoryForCurrentStation() {
        guard let station = currentStation,
              let start = sessionStartTime else { return }

        // Active listening time only — paused time is excluded.
        var duration = accumulatedPlayTime
        if let segStart = segmentStartTime {
            duration += Date().timeIntervalSince(segStart)
        }
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

        saveHistoryToDisk()
    }
}
