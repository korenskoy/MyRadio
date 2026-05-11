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
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    var artwork600: URL? {
        guard let s = artworkURL else { return nil }
        return URL(string: s)
    }
}

/// Fetches track data from the iTunes Search API.
actor iTunesArtworkService {
    static let shared = iTunesArtworkService()

    private var tracksCache: [String: [iTunesTrack]] = [:]
    private var imageCache:  [String: NSImage] = [:]
    private var inFlightTracks: [String: Task<[iTunesTrack], Never>] = [:]
    private var inFlightImages: [String: Task<NSImage?, Never>] = [:]

    // MARK: - Public

    func tracks(artist: String, title: String) async -> [iTunesTrack] {
        let key = cacheKey(artist, title)
        if let c = tracksCache[key] { return c }
        if let t = inFlightTracks[key] { return await t.value }

        let task = Task<[iTunesTrack], Never> {
            let result = await fetchTracks(artist: artist, title: title)
            tracksCache[key] = result
            inFlightTracks.removeValue(forKey: key)
            return result
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
        if let c = imageCache[key] { return c }
        if let t = inFlightImages[key] { return await t.value }

        let task = Task<NSImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = NSImage(data: data) else { return nil }
            imageCache[key] = img
            inFlightImages.removeValue(forKey: key)
            return img
        }
        inFlightImages[key] = task
        return await task.value
    }

    // MARK: - Private

    private func cacheKey(_ artist: String, _ title: String) -> String {
        "\(artist)|\(title)".lowercased()
    }

    private func fetchTracks(artist: String, title: String) async -> [iTunesTrack] {
        let term = "\(artist) \(title)"
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=8")
        else { return [] }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return [] }

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
