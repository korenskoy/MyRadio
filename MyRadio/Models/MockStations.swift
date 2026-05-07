import Foundation
import RadioBrowserKit

// MARK: - Mock factory

private func makeStation(
    uuid: String, name: String, url: String,
    countrycode: String? = nil, language: String? = nil, tags: String? = nil,
    codec: String? = nil, bitrate: Int? = nil, hls: Bool = false,
    votes: Int? = nil, clickcount: Int? = nil, clicktrend: Int? = nil
) -> Station {
    var d: [String: Any] = [
        "stationuuid": uuid,
        "name": name,
        "url": url
    ]
    if let v = countrycode { d["countrycode"] = v }
    if let v = language    { d["language"] = v }
    if let v = tags        { d["tags"] = v }
    if let v = codec       { d["codec"] = v }
    if let v = bitrate     { d["bitrate"] = v }
    d["hls"] = hls ? 1 : 0
    if let v = votes       { d["votes"] = v }
    if let v = clickcount  { d["clickcount"] = v }
    if let v = clicktrend  { d["clicktrend"] = v }

    let data = try! JSONSerialization.data(withJSONObject: d)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return try! decoder.decode(Station.self, from: data)
}

// MARK: - Mock data (port of data.js)

enum MockData {
    static let stations: [Station] = [
        makeStation(
            uuid: "a1", name: "FIP",
            url: "https://stream.radiofrance.fr/fip/fip.m3u8",
            countrycode: "FR", language: "french",
            tags: "jazz,eclectic,world,public radio",
            codec: "MP3", bitrate: 128, hls: true,
            votes: 4823, clickcount: 28471, clicktrend: 12
        ),
        makeStation(
            uuid: "a2", name: "BBC Radio 6 Music",
            url: "https://stream.live.vc.bbcmedia.co.uk/bbc_6music",
            countrycode: "GB", language: "english",
            tags: "alternative,indie,rock,public radio",
            codec: "AAC", bitrate: 320, hls: true,
            votes: 12104, clickcount: 89342, clicktrend: 5
        ),
        makeStation(
            uuid: "a3", name: "KCRW Eclectic 24",
            url: "https://kcrw.streamguys1.com/kcrw_192k_mp3_e24",
            countrycode: "US", language: "english",
            tags: "eclectic,alternative,indie,discovery",
            codec: "AAC", bitrate: 256, hls: true,
            votes: 7821, clickcount: 54221, clicktrend: 8
        ),
        makeStation(
            uuid: "a4", name: "NTS Radio 1",
            url: "https://stream-relay-geo.ntslive.net/stream",
            countrycode: "GB", language: "english",
            tags: "underground,experimental,electronic,global",
            codec: "MP3", bitrate: 192,
            votes: 9430, clickcount: 71203, clicktrend: 15
        ),
        makeStation(
            uuid: "a5", name: "SomaFM Groove Salad",
            url: "https://ice1.somafm.com/groovesalad-256-mp3",
            countrycode: "US", language: "english",
            tags: "downtempo,ambient,chill,electronic",
            codec: "AAC", bitrate: 128,
            votes: 15203, clickcount: 112045, clicktrend: 3
        ),
        makeStation(
            uuid: "a6", name: "Radio Paradise (Main Mix)",
            url: "https://stream.radioparadise.com/aac-320",
            countrycode: "US", language: "english",
            tags: "eclectic,rock,world,discovery",
            codec: "FLAC", bitrate: 850, hls: true,
            votes: 18420, clickcount: 143892, clicktrend: 7
        ),
        makeStation(
            uuid: "a7", name: "Маяк",
            url: "https://icecast.vgtrk.cdnvideo.ru/mayak_hi",
            countrycode: "RU", language: "russian",
            tags: "news,talk,public radio",
            codec: "MP3", bitrate: 128,
            votes: 2104, clickcount: 18432, clicktrend: 1
        ),
        makeStation(
            uuid: "a8", name: "Ø MANUAL Tigle FM (Local)",
            url: "https://stream.example.fm/listen.m3u",
            tags: "custom,local,ambient",
            codec: "MP3", bitrate: 192,
            votes: 0, clickcount: 0
        ),
        makeStation(
            uuid: "a9", name: "Boxout.fm",
            url: "https://boxout.fm/stream",
            countrycode: "IN", language: "english",
            tags: "underground,electronic,world,discovery",
            codec: "MP3", bitrate: 192,
            votes: 1832, clickcount: 14201, clicktrend: 4
        ),
        makeStation(
            uuid: "a10", name: "Rinse FM",
            url: "https://rinse.fm/stream",
            countrycode: "GB", language: "english",
            tags: "dance,house,garage,electronic",
            codec: "AAC", bitrate: 128, hls: true,
            votes: 6240, clickcount: 48201, clicktrend: 6
        ),
        makeStation(
            uuid: "a11", name: "Radio Nova",
            url: "https://nova.fm/stream",
            countrycode: "FR", language: "french",
            tags: "world,hip hop,soul,eclectic",
            codec: "AAC", bitrate: 128,
            votes: 3820, clickcount: 28104, clicktrend: 3
        ),
        makeStation(
            uuid: "a12", name: "WFMU",
            url: "https://wfmu.org/stream",
            countrycode: "US", language: "english",
            tags: "freeform,experimental,eclectic,college",
            codec: "MP3", bitrate: 128,
            votes: 5920, clickcount: 41203, clicktrend: 5
        ),
    ]

    static let defaultFavorites: Set<String> = ["a1", "a2", "a5", "a6", "a8"]

    static let history: [HistoryEntry] = [
        HistoryEntry(id: UUID(), stationUUID: "a2", stationName: "BBC Radio 6 Music",
                     playedAt: Date().addingTimeInterval(-3600), duration: 5040),
        HistoryEntry(id: UUID(), stationUUID: "a5", stationName: "SomaFM Groove Salad",
                     playedAt: Date().addingTimeInterval(-14400), duration: 8040),
        HistoryEntry(id: UUID(), stationUUID: "a1", stationName: "FIP",
                     playedAt: Date().addingTimeInterval(-18000), duration: 2820),
        HistoryEntry(id: UUID(), stationUUID: "a6", stationName: "Radio Paradise (Main Mix)",
                     playedAt: Date().addingTimeInterval(-86400 - 3600), duration: 10920),
        HistoryEntry(id: UUID(), stationUUID: "a3", stationName: "KCRW Eclectic 24",
                     playedAt: Date().addingTimeInterval(-86400 - 18000), duration: 4680),
        HistoryEntry(id: UUID(), stationUUID: "a10", stationName: "Rinse FM",
                     playedAt: Date().addingTimeInterval(-86400 - 43200), duration: 1920),
        HistoryEntry(id: UUID(), stationUUID: "a12", stationName: "WFMU",
                     playedAt: Date().addingTimeInterval(-86400 - 50400), duration: 6420),
        HistoryEntry(id: UUID(), stationUUID: "a4", stationName: "NTS Radio 1",
                     playedAt: Date().addingTimeInterval(-172800 - 7200), duration: 7860),
        HistoryEntry(id: UUID(), stationUUID: "a7", stationName: "Маяк",
                     playedAt: Date().addingTimeInterval(-172800 - 36000), duration: 3480),
        HistoryEntry(id: UUID(), stationUUID: "a9", stationName: "Boxout.fm",
                     playedAt: Date().addingTimeInterval(-259200 - 10800), duration: 3840),
        HistoryEntry(id: UUID(), stationUUID: "a2", stationName: "BBC Radio 6 Music",
                     playedAt: Date().addingTimeInterval(-259200 - 50000), duration: 11880),
    ]

    static let tags: [(name: String, count: Int)] = [
        ("jazz", 1248), ("rock", 4128), ("electronic", 2843), ("ambient", 421),
        ("indie", 1320), ("house", 892), ("techno", 1104), ("classical", 723),
        ("news", 3402), ("talk", 2148), ("pop", 5821), ("hip hop", 1432),
        ("reggae", 312), ("country", 1023), ("blues", 489), ("soul", 612),
        ("funk", 287), ("world", 1842), ("alternative", 2104), ("metal", 1342),
        ("punk", 482), ("downtempo", 198), ("experimental", 421), ("lounge", 312),
        ("soundtrack", 142), ("drum and bass", 234), ("garage", 121), ("disco", 287),
        ("synthwave", 184), ("lo-fi", 312), ("folk", 824), ("latin", 1432),
        ("spanish", 2103), ("french", 1432), ("german", 1820), ("italian", 821),
        ("ambient electronic", 84),
    ]

    static let countries: [(code: String, name: String, count: Int, flag: String)] = [
        ("US", "United States", 8421, "🇺🇸"), ("DE", "Germany", 3120, "🇩🇪"),
        ("GB", "United Kingdom", 2843, "🇬🇧"), ("FR", "France", 2104, "🇫🇷"),
        ("ES", "Spain", 1843, "🇪🇸"), ("IT", "Italy", 1420, "🇮🇹"),
        ("BR", "Brazil", 1342, "🇧🇷"), ("RU", "Russia", 1230, "🇷🇺"),
        ("JP", "Japan", 920, "🇯🇵"), ("MX", "Mexico", 821, "🇲🇽"),
        ("PL", "Poland", 814, "🇵🇱"), ("CA", "Canada", 712, "🇨🇦"),
        ("NL", "Netherlands", 632, "🇳🇱"), ("AU", "Australia", 581, "🇦🇺"),
        ("AR", "Argentina", 510, "🇦🇷"), ("TR", "Turkey", 481, "🇹🇷"),
        ("IN", "India", 423, "🇮🇳"), ("GR", "Greece", 385, "🇬🇷"),
        ("PT", "Portugal", 342, "🇵🇹"), ("SE", "Sweden", 318, "🇸🇪"),
    ]
}

// MARK: - Debug mock data

struct LogLine: Identifiable {
    let id = UUID()
    let time: String
    let level: LogLevel
    let message: String
    let source: String

    enum LogLevel: String {
        case info, debug, warn, error
    }
}

enum MockDebug {
    static let logs: [LogLine] = [
        LogLine(time: "14:48:02.412", level: .info,  message: "Stream connected",                                              source: "audio.player"),
        LogLine(time: "14:48:02.398", level: .info,  message: "GET /icy?stationuuid=a1 → 200 OK (audio/mpeg, icy-br=128)",    source: "icy.client"),
        LogLine(time: "14:48:02.301", level: .debug, message: "Picked stream URL: https://stream.radiofrance.fr/fip/fip.m3u8", source: "stream.resolver"),
        LogLine(time: "14:48:02.108", level: .info,  message: "Click registered for station a1",                              source: "rb.client"),
        LogLine(time: "14:48:01.982", level: .info,  message: "User played station: FIP (uuid=a1)",                           source: "ui.action"),
        LogLine(time: "14:48:01.640", level: .warn,  message: "Server de1.api.radio-browser.info responded slowly (842ms)",   source: "rb.health"),
        LogLine(time: "14:47:58.302", level: .info,  message: "Loaded 124 stations from /json/stations/topvote/200",          source: "rb.client"),
        LogLine(time: "14:47:55.212", level: .debug, message: "Cache hit: tags (TTL 240s)",                                   source: "rb.cache"),
        LogLine(time: "14:47:54.108", level: .error, message: "Stream connection lost; retrying in 1.5s",                     source: "audio.player"),
        LogLine(time: "14:47:53.842", level: .error, message: "ECONNRESET on https://nl1.api.radio-browser.info — failing over", source: "rb.client"),
        LogLine(time: "14:47:50.404", level: .info,  message: "Application started · v1.0.0-beta.4",                         source: "app.boot"),
        LogLine(time: "14:47:50.389", level: .debug, message: "Resolved DNS all.api.radio-browser.info → 4 hosts",           source: "rb.dns"),
    ]

    struct NetLine: Identifiable {
        let id = UUID()
        let time: String
        let method: String
        let status: Int
        let url: String
        let ms: Int
        let size: String
        var isStream = false
    }

    static let network: [NetLine] = [
        NetLine(time: "14:48:02.5", method: "GET",  status: 200, url: "/json/url/a1",                                             ms: 142, size: "1.2 KB"),
        NetLine(time: "14:48:02.4", method: "GET",  status: 200, url: "https://stream.radiofrance.fr/fip/fip.m3u8",               ms: 287, size: "184 KB", isStream: true),
        NetLine(time: "14:48:02.1", method: "POST", status: 200, url: "/json/url/click/a1",                                       ms: 84,  size: "120 B"),
        NetLine(time: "14:47:58.3", method: "GET",  status: 200, url: "/json/stations/topvote/200",                               ms: 412, size: "84.2 KB"),
        NetLine(time: "14:47:54.2", method: "GET",  status: 200, url: "/json/stations/bytag/jazz?limit=100",                      ms: 318, size: "42.1 KB"),
        NetLine(time: "14:47:54.1", method: "GET",  status: 0,   url: "https://nl1.api.radio-browser.info/json/stations/bytag/jazz", ms: 8000, size: "—"),
        NetLine(time: "14:47:52.0", method: "GET",  status: 200, url: "/json/countries",                                          ms: 142, size: "8.4 KB"),
        NetLine(time: "14:47:51.8", method: "GET",  status: 200, url: "/json/tags?limit=200",                                     ms: 218, size: "6.2 KB"),
        NetLine(time: "14:47:51.4", method: "GET",  status: 304, url: "/json/stats",                                              ms: 42,  size: "0 B"),
        NetLine(time: "14:47:50.4", method: "DNS",  status: 200, url: "all.api.radio-browser.info",                               ms: 38,  size: "—"),
    ]

    static let icyData: [(key: String, value: String)] = [
        ("icy-name", "FIP"),
        ("icy-genre", "Eclectic"),
        ("icy-br", "128"),
        ("icy-sr", "44100"),
        ("icy-pub", "1"),
        ("icy-url", "https://www.fip.fr"),
        ("icy-description", "Radio France · FIP — Toute la musique"),
        ("ice-audio-info", "ice-samplerate=44100;ice-bitrate=128;ice-channels=2"),
        ("content-type", "audio/mpeg"),
        ("metaint", "16000"),
        ("StreamTitle", "Alice Coltrane - Journey in Satchidananda"),
        ("StreamUrl", "https://www.fip.fr/musique/alice-coltrane"),
    ]

    struct ServerEntry: Identifiable {
        let id = UUID()
        let host: String
        let ip: String
        let region: String
        let latency: Int?
        let isActive: Bool
        let isBroken: Bool
    }

    static let servers: [ServerEntry] = [
        ServerEntry(host: "de1.api.radio-browser.info", ip: "188.68.62.16",    region: "DE", latency: 28,   isActive: true,  isBroken: false),
        ServerEntry(host: "de2.api.radio-browser.info", ip: "78.46.83.121",    region: "DE", latency: 31,   isActive: false, isBroken: false),
        ServerEntry(host: "nl1.api.radio-browser.info", ip: "95.179.139.106",  region: "NL", latency: 42,   isActive: false, isBroken: false),
        ServerEntry(host: "at1.api.radio-browser.info", ip: "94.16.115.17",    region: "AT", latency: 56,   isActive: false, isBroken: false),
        ServerEntry(host: "fr1.api.radio-browser.info", ip: "51.158.108.12",   region: "FR", latency: 18,   isActive: false, isBroken: true),
    ]
}
