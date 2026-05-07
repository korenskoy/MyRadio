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
            votes: 4823, clickcount: 15200, clicktrend: 12
        ),
        makeStation(
            uuid: "a2", name: "BBC Radio 6 Music",
            url: "https://stream.live.vc.bbcmedia.co.uk/bbc_6music",
            countrycode: "GB", language: "english",
            tags: "alternative,indie,rock",
            codec: "AAC", bitrate: 320,
            votes: 12100, clickcount: 31000, clicktrend: 5
        ),
        makeStation(
            uuid: "a3", name: "KCRW Eclectic 24",
            url: "https://kcrw.streamguys1.com/kcrw_192k_mp3_e24",
            countrycode: "US", language: "english",
            tags: "eclectic,alternative,indie",
            codec: "AAC", bitrate: 256,
            votes: 7800, clickcount: 22000, clicktrend: 8
        ),
        makeStation(
            uuid: "a4", name: "NTS Radio 1",
            url: "https://stream-relay-geo.ntslive.net/stream",
            countrycode: "GB", language: "english",
            tags: "underground,experimental,electronic",
            codec: "MP3", bitrate: 192,
            votes: 9400, clickcount: 18000, clicktrend: 15
        ),
        makeStation(
            uuid: "a5", name: "SomaFM Groove Salad",
            url: "https://ice1.somafm.com/groovesalad-256-mp3",
            countrycode: "US", language: "english",
            tags: "downtempo,ambient,chill",
            codec: "AAC", bitrate: 128,
            votes: 15200, clickcount: 44000, clicktrend: 3
        ),
        makeStation(
            uuid: "a6", name: "Radio Paradise (Main Mix)",
            url: "https://stream.radioparadise.com/aac-320",
            countrycode: "US", language: "english",
            tags: "eclectic,rock,adult",
            codec: "FLAC", bitrate: 850,
            votes: 18400, clickcount: 55000, clicktrend: 7
        ),
        makeStation(
            uuid: "a7", name: "Маяк",
            url: "https://icecast.vgtrk.cdnvideo.ru/mayak_hi",
            countrycode: "RU", language: "russian",
            tags: "news,talk",
            codec: "MP3", bitrate: 128,
            votes: 2100, clickcount: 6000, clicktrend: 1
        ),
    ]

    static let history: [HistoryEntry] = [
        HistoryEntry(id: UUID(), stationUUID: "a1", stationName: "FIP",
                     playedAt: Date().addingTimeInterval(-3600), duration: 2340),
        HistoryEntry(id: UUID(), stationUUID: "a4", stationName: "NTS Radio 1",
                     playedAt: Date().addingTimeInterval(-7200), duration: 1560),
        HistoryEntry(id: UUID(), stationUUID: "a3", stationName: "KCRW Eclectic 24",
                     playedAt: Date().addingTimeInterval(-86400), duration: 3600),
        HistoryEntry(id: UUID(), stationUUID: "a5", stationName: "SomaFM Groove Salad",
                     playedAt: Date().addingTimeInterval(-90000), duration: 4200),
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
        LogLine(time: "14:47:54.212", level: .debug, message: "Cache hit: tags (TTL 240s)",                                   source: "rb.cache"),
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
        NetLine(time: "14:47:54.1", method: "GET",  status: 0,   url: "https://nl1.api.radio-browser.info/json/tags",             ms: 5000, size: "—"),
    ]

    struct ServerEntry: Identifiable {
        let id = UUID()
        let host: String
        let latency: Int?
        let isActive: Bool
    }

    static let servers: [ServerEntry] = [
        ServerEntry(host: "de1.api.radio-browser.info", latency: 42,   isActive: true),
        ServerEntry(host: "nl1.api.radio-browser.info", latency: 88,   isActive: false),
        ServerEntry(host: "at1.api.radio-browser.info", latency: 61,   isActive: false),
        ServerEntry(host: "de2.api.radio-browser.info", latency: nil,  isActive: false),
        ServerEntry(host: "fi1.api.radio-browser.info", latency: 120,  isActive: false),
    ]
}
