import Foundation

enum TabKind: String, CaseIterable, Identifiable {
    case discover
    case favorites
    case search
    case topVoted   = "top_voted"
    case popular
    case tags
    case countries
    case map
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discover:  return "Discover"
        case .favorites: return "Favorites"
        case .search:    return "Search"
        case .topVoted:  return "Top voted"
        case .popular:   return "Popular"
        case .tags:      return "Tags"
        case .countries: return "Countries"
        case .map:       return "Map"
        case .history:   return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .discover:  return "flame"
        case .favorites: return "heart.fill"
        case .search:    return "magnifyingglass"
        case .topVoted:  return "chart.line.uptrend.xyaxis"
        case .popular:   return "flame.fill"
        case .tags:      return "tag"
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
    case icy      = "icy_metadata"
    case servers

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logs:    return "Logs"
        case .network: return "Network"
        case .stream:  return "Stream"
        case .icy:     return "ICY metadata"
        case .servers: return "Servers"
        }
    }
}
