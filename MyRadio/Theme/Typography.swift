import SwiftUI

enum Typography {
    // Station name in player
    static let stationName    = Font.system(size: 26, weight: .bold, design: .default)
    // Section headers
    static let sectionHeader  = Font.system(size: 13, weight: .semibold)
    // Titlebar title
    static let titlebar       = Font.system(size: 13, weight: .semibold)
    // Tab labels
    static let tab            = Font.system(size: 13, weight: .medium)
    // Body / station row name
    static let body           = Font.system(size: 13, weight: .medium)
    // Secondary meta
    static let meta           = Font.system(size: 11.5, weight: .regular)
    // Small tags
    static let tag            = Font.system(size: 10.5, weight: .medium)
    // Tiny labels (NOW ON AIR)
    static let label          = Font.system(size: 9.5, weight: .bold)
    // Monospace (row numbers, debug, volume)
    static let mono           = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monoSm         = Font.system(size: 11, weight: .regular, design: .monospaced)
    // Glyph in cover art
    static let coverGlyph     = Font.system(size: 96, weight: .heavy, design: .default)
    // Volume value
    static let volume         = Font.system(size: 12, weight: .regular, design: .monospaced)
    // Utility bar buttons
    static let utility        = Font.system(size: 11.5, weight: .medium)
    // Search input
    static let searchInput    = Font.system(size: 13, weight: .regular)
    // Country / tag count
    static let countLg        = Font.system(size: 18, weight: .semibold, design: .monospaced)
    // Debug log
    static let debugLog       = Font.system(size: 11.5, weight: .regular, design: .monospaced)
    static let debugLabel     = Font.system(size: 10, weight: .bold)
}
