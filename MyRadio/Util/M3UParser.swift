import Foundation

enum M3UParser {
    static func parse(_ text: String) -> [CustomStation] {
        let lines = text.components(separatedBy: .newlines)
        var stations: [CustomStation] = []
        var pendingName: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "#EXTM3U" { continue }

            if trimmed.hasPrefix("#EXTINF:") {
                // Format: #EXTINF:duration,Station Name
                let afterPrefix = String(trimmed.dropFirst("#EXTINF:".count))
                if let commaIndex = afterPrefix.firstIndex(of: ",") {
                    pendingName = String(afterPrefix[afterPrefix.index(after: commaIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if trimmed.hasPrefix("#") { continue }

            // Treat as URL line
            guard trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") else {
                pendingName = nil
                continue
            }

            let name = pendingName ?? urlToFallbackName(trimmed)
            stations.append(CustomStation(
                id: UUID(),
                name: name,
                url: trimmed,
                addedAt: Date()
            ))
            pendingName = nil
        }

        return stations
    }

    static func export(_ stations: [CustomStation]) -> String {
        var lines = ["#EXTM3U"]
        for station in stations {
            lines.append("#EXTINF:-1,\(station.name)")
            lines.append(station.url)
        }
        return lines.joined(separator: "\n")
    }

    private static func urlToFallbackName(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }
}
