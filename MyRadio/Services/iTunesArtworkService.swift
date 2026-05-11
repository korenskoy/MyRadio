import AppKit

/// Fetches track artwork from the iTunes Search API.
/// Free, no auth required. Falls back to nil if not found.
actor iTunesArtworkService {
    static let shared = iTunesArtworkService()

    private var cache: [String: NSImage?] = [:]
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func artwork(artist: String, title: String) async -> NSImage? {
        let key = "\(artist)|\(title)".lowercased()

        if let cached = cache[key] { return cached }
        if let task = inFlight[key] { return await task.value }

        let task = Task<NSImage?, Never> {
            let result = await fetch(artist: artist, title: title)
            cache[key] = result
            inFlight.removeValue(forKey: key)
            return result
        }
        inFlight[key] = task
        return await task.value
    }

    private func fetch(artist: String, title: String) async -> NSImage? {
        let term = "\(artist) \(title)"
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=3")
        else { return nil }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              var artworkURL = first["artworkUrl100"] as? String
        else { return nil }

        // Upgrade to 600×600
        artworkURL = artworkURL.replacingOccurrences(of: "100x100bb", with: "600x600bb")

        guard let imgURL = URL(string: artworkURL),
              let (imgData, _) = try? await URLSession.shared.data(from: imgURL)
        else { return nil }

        return NSImage(data: imgData)
    }
}
