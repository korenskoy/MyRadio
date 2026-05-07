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

    // Deterministic gradient pair from stationuuid
    var gradientColors: (Color, Color) {
        gradientPair(seed: stationuuid)
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

    var countryFlag: String {
        guard let code = countrycode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar($0.value + 127397) }
            .map(String.init)
            .joined()
    }
}

// MARK: - Color hash

private let gradientPalette: [(UInt32, UInt32)] = [
    (0x8B3A5E, 0x3A1A4A),  // maroon → deep purple
    (0x2E6B8A, 0x1A3A4A),  // teal → dark blue
    (0x6B4A2E, 0x3A2A1A),  // warm brown → dark brown
    (0x3A6B4A, 0x1A3A2E),  // forest → dark green
    (0x6B3A6B, 0x2E1A3A),  // plum → dark violet
    (0x8A5E2E, 0x4A2E1A),  // amber → dark amber
    (0x2E5E8A, 0x1A2E4A),  // steel blue → dark navy
    (0x6B5E2E, 0x3A2E1A),  // olive → dark olive
]

private func gradientPair(seed: String) -> (Color, Color) {
    let bytes = seed.utf8.prefix(4)
    let idx = Int(bytes.reduce(0, { ($0 &* 31) &+ UInt32($1) })) % gradientPalette.count
    let (c1, c2) = gradientPalette[idx]
    return (Color(hex: c1), Color(hex: c2))
}
