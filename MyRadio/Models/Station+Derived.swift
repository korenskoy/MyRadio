import SwiftUI
import RadioBrowserKit

// MARK: - Derived display properties (not in API)

extension Station {
    var glyph: String {
        name.first.map(String.init) ?? "♪"
    }

    var tagList: [String] {
        tags?.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ?? []
    }

    var gradientColors: (Color, Color) {
        gradientPair(seed: stationuuid)
    }

    var bitrateFormatted: String? {
        guard let br = bitrate, br > 0 else { return nil }
        return "\(br.formatted())k"
    }

    var codecDisplay: String? {
        codec?.uppercased()
    }

    var votesFormatted: String {
        guard let v = votes else { return 0.formatted() }
        if v >= 1000 {
            return String(format: "%.1fk", locale: Locale.current, Double(v) / 1000)
        }
        return v.formatted()
    }

    var votesLocalized: String {
        guard let v = votes else { return "0" }
        return v.formatted()
    }

    var countryFlag: String {
        guard let code = countrycode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar($0.value + 127397) }
            .map(String.init)
            .joined()
    }

    var countryName: String {
        guard let code = countrycode, code.count == 2 else { return String(localized: "Custom") }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

// MARK: - Deterministic per-station gradient

private let gradientPalette: [(UInt32, UInt32)] = [
    (0x8B3A5E, 0x3A1A4A),
    (0x2E6B8A, 0x1A3A4A),
    (0x6B4A2E, 0x3A2A1A),
    (0x3A6B4A, 0x1A3A2E),
    (0x6B3A6B, 0x2E1A3A),
    (0x8A5E2E, 0x4A2E1A),
    (0x2E5E8A, 0x1A2E4A),
    (0x6B5E2E, 0x3A2E1A),
]

private func gradientPair(seed: String) -> (Color, Color) {
    let bytes = seed.utf8.prefix(4)
    let idx = Int(bytes.reduce(0, { ($0 &* 31) &+ UInt32($1) })) % gradientPalette.count
    let (c1, c2) = gradientPalette[idx]
    return (Color(hex: c1), Color(hex: c2))
}
