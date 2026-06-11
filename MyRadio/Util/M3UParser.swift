import Foundation
import RadioBrowserKit

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
        for s in stations {
            lines.append("#EXTINF:-1,\(sanitizeName(s.name))")
            lines.append(s.url)
        }
        return lines.joined(separator: "\n")
    }

    static func export(_ stations: [Station]) -> String {
        var lines = ["#EXTM3U"]
        for s in stations {
            lines.append("#EXTINF:-1,\(sanitizeName(s.name))")
            lines.append(s.urlResolved ?? s.url)
        }
        return lines.joined(separator: "\n")
    }

    /// Strips newlines from a station name so it can't break the line-oriented
    /// M3U structure (and spawn phantom entries on re-import).
    private static func sanitizeName(_ name: String) -> String {
        name.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func urlToFallbackName(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }
}
