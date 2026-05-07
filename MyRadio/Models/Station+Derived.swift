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
        let pair = stationGradients[stationuuid] ?? gradientPair(seed: stationuuid)
        return pair
    }

    var bitrateFormatted: String? {
        guard let br = bitrate, br > 0 else { return nil }
        return "\(br)k"
    }

    var codecDisplay: String? {
        codec?.uppercased()
    }

    var votesFormatted: String {
        guard let v = votes else { return "0" }
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000) }
        return "\(v)"
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
        guard let code = countrycode, code.count == 2 else { return "Custom" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

// MARK: - Per-station gradient colors (from data.js cover field)

private let stationGradients: [String: (Color, Color)] = [
    "a1":  (Color(hex: 0xE85D75), Color(hex: 0x2D1B3A)),
    "a2":  (Color(hex: 0xFF4040), Color(hex: 0x1A1A1A)),
    "a3":  (Color(hex: 0x0066CC), Color(hex: 0x001A33)),
    "a4":  (Color(hex: 0x000000), Color(hex: 0x222222)),
    "a5":  (Color(hex: 0x7CBA47), Color(hex: 0x1A3320)),
    "a6":  (Color(hex: 0xD4751C), Color(hex: 0x3D1D05)),
    "a7":  (Color(hex: 0x1A73E8), Color(hex: 0x0A1A3A)),
    "a8":  (Color(hex: 0x444444), Color(hex: 0x1A1A1A)),
    "a9":  (Color(hex: 0xFF7A40), Color(hex: 0x3A1A05)),
    "a10": (Color(hex: 0xFF2D8E), Color(hex: 0x220A14)),
    "a11": (Color(hex: 0x0A0A0A), Color(hex: 0x2D2D2D)),
    "a12": (Color(hex: 0xFBBF24), Color(hex: 0x3D2A05)),
]

// MARK: - Fallback gradient hash

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
