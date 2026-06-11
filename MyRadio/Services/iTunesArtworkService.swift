import AppKit

struct iTunesTrack: Identifiable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let year: Int?
    let genre: String?
    let durationMs: Int?
    let country: String?
    let price: Double?
    let currency: String?
    let artworkURL: String?      // 600×600
    let previewURL: String?
    let trackViewURL: String?    // Apple Music

    var duration: String? {
        guard let ms = durationMs else { return nil }
        let s = ms / 1000
        let mins = (s / 60).formatted()
        let secs = String(format: "%02d", locale: Locale.current, s % 60)
        return "\(mins):\(secs)"
    }

    var artwork600: URL? {
        guard let s = artworkURL else { return nil }
        return URL(string: s)
    }
}

/// Boxes a value-type track array so it can live in an `NSCache` (which only
/// holds class instances).
private final class TracksBox {
    let tracks: [iTunesTrack]
    init(_ tracks: [iTunesTrack]) { self.tracks = tracks }
}

/// Fetches track data from the iTunes Search API.
actor iTunesArtworkService {
    static let shared = iTunesArtworkService()

    // Bounded so a long listening session can't grow these without limit.
    private let tracksCache: NSCache<NSString, TracksBox> = {
        let c = NSCache<NSString, TracksBox>()
        c.countLimit = 200
        return c
    }()
    private let imageCache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 100
        return c
    }()
    private var inFlightTracks: [String: Task<[iTunesTrack], Never>] = [:]
    private var inFlightImages: [String: Task<NSImage?, Never>] = [:]

    // MARK: - Public

    func tracks(artist: String, title: String) async -> [iTunesTrack] {
        let key = cacheKey(artist, title)
        if let c = tracksCache.object(forKey: key as NSString) { return c.tracks }
        if let t = inFlightTracks[key] { return await t.value }

        let task = Task<[iTunesTrack], Never> {
            let result = await fetchTracks(artist: artist, title: title)
            // Only cache a real response (incl. a legitimately empty result set).
            // A transport/HTTP failure returns nil and is left uncached so the
            // next attempt retries instead of being stuck empty for the session.
            if let result {
                tracksCache.setObject(TracksBox(result), forKey: key as NSString)
            }
            inFlightTracks.removeValue(forKey: key)
            return result ?? []
        }
        inFlightTracks[key] = task
        return await task.value
    }

    func artwork(artist: String, title: String) async -> NSImage? {
        let t = await tracks(artist: artist, title: title)
        guard let url = t.first?.artwork600 else { return nil }
        return await image(from: url)
    }

    func image(from url: URL) async -> NSImage? {
        let key = url.absoluteString
        if let c = imageCache.object(forKey: url as NSURL) { return c }
        if let t = inFlightImages[key] { return await t.value }

        let task = Task<NSImage?, Never> {
            defer { inFlightImages.removeValue(forKey: key) }
            guard let (data, response) = try? await NetworkActivityLog.shared.tracked(url),
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let img = NSImage(data: data) else { return nil }
            imageCache.setObject(img, forKey: url as NSURL)
            return img
        }
        inFlightImages[key] = task
        return await task.value
    }

    // MARK: - Private

    private func cacheKey(_ artist: String, _ title: String) -> String {
        "\(artist)|\(title)".lowercased()
    }

    /// Returns `nil` on transport/HTTP/parse failure (so the caller won't cache
    /// it), or an array (possibly empty) on a successful 2xx response.
    private func fetchTracks(artist: String, title: String) async -> [iTunesTrack]? {
        var comps = URLComponents(string: "https://itunes.apple.com/search")
        comps?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "8"),
        ]
        guard let url = comps?.url else { return [] }

        guard let (data, response) = try? await NetworkActivityLog.shared.tracked(url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return nil }

        return results.compactMap { r in
            guard let id    = r["trackId"]   as? Int,
                  let title = r["trackName"] as? String,
                  let artist = r["artistName"] as? String,
                  let album  = r["collectionName"] as? String
            else { return nil }

            var art = r["artworkUrl100"] as? String
            art = art?.replacingOccurrences(of: "100x100bb", with: "600x600bb")

            let year: Int? = (r["releaseDate"] as? String).flatMap {
                Int($0.prefix(4))
            }
            return iTunesTrack(
                id:           id,
                title:        title,
                artist:       artist,
                album:        album,
                year:         year,
                genre:        r["primaryGenreName"] as? String,
                durationMs:   r["trackTimeMillis"]  as? Int,
                country:      r["country"]          as? String,
                price:        r["trackPrice"]       as? Double,
                currency:     r["currency"]         as? String,
                artworkURL:   art,
                previewURL:   r["previewUrl"]       as? String,
                trackViewURL: r["trackViewUrl"]     as? String
            )
        }
    }
}
