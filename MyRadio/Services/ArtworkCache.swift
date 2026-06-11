import AppKit

actor ArtworkCache {
    static let shared = ArtworkCache()

    private let diskDir: URL
    private let ttl: TimeInterval = 30 * 86400
    private var memoryCache: [String: NSImage] = [:]
    private var activeDownloads: [String: Task<NSImage?, Never>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDir = caches.appendingPathComponent("MyRadio/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    func image(for stationUUID: String, faviconURL: String?) async -> NSImage? {
        if let img = memoryCache[stationUUID] {
            return img
        }

        let fileURL = diskDir.appendingPathComponent(stationUUID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let modDate = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) < ttl,
               let data = try? Data(contentsOf: fileURL),
               let img = NSImage(data: data) {
                memoryCache[stationUUID] = img
                return img
            }
            try? FileManager.default.removeItem(at: fileURL)
        }

        guard let faviconURL,
              !faviconURL.isEmpty,
              let url = URL(string: faviconURL) else {
            return nil
        }

        if let existing = activeDownloads[stationUUID] {
            return await existing.value
        }

        let dest = fileURL
        let task = Task<NSImage?, Never> {
            do {
                let (data, response) = try await NetworkActivityLog.shared.tracked(url)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      data.count > 100,
                      let img = NSImage(data: data) else {
                    return nil
                }
                try? data.write(to: dest, options: .atomic)
                return img
            } catch {
                return nil
            }
        }
        activeDownloads[stationUUID] = task
        let result = await task.value
        activeDownloads[stationUUID] = nil
        if let result {
            memoryCache[stationUUID] = result
        }
        return result
    }

    func clearMemory() {
        memoryCache.removeAll()
    }

    func clearAll() {
        memoryCache.removeAll()
        activeDownloads.values.forEach { $0.cancel() }
        activeDownloads.removeAll()
        try? FileManager.default.removeItem(at: diskDir)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    func diskUsage() -> UInt64 {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: diskDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return urls.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + UInt64(size)
        }
    }
}
