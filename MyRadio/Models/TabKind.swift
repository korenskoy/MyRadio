import Foundation

enum TabKind: String, Codable, CaseIterable, Identifiable {
    case discover
    case favorites
    case search
    case topVoted   = "top_voted"
    case popular
    case countries
    case map
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discover:  return String(localized: "Discover")
        case .favorites: return String(localized: "Favorites")
        case .search:    return String(localized: "Search")
        case .topVoted:  return String(localized: "Top voted")
        case .popular:   return String(localized: "Popular")
        case .countries: return String(localized: "Countries")
        case .map:       return String(localized: "Map")
        case .history:   return String(localized: "History")
        }
    }

    var systemImage: String {
        switch self {
        case .discover:  return "flame"
        case .favorites: return "heart.fill"
        case .search:    return "magnifyingglass"
        case .topVoted:  return "chart.line.uptrend.xyaxis"
        case .popular:   return "flame.fill"
        case .countries: return "globe"
        case .map:       return "map"
        case .history:   return "clock"
        }
    }
}

enum DebugTab: String, CaseIterable, Identifiable {
    case logs
    case network
    case stream
    case servers

    var id: String { rawValue }

    /// DevTools panel — developer-facing, kept in English on purpose.
    var label: String {
        switch self {
        case .logs:    return "Logs"
        case .network: return "Network"
        case .stream:  return "Stream"
        case .servers: return "Servers"
        }
    }
}
