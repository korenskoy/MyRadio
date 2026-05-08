import SwiftUI

struct BrowsePanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            SearchBar()
            TabsBar()

            if state.activeTab == .map {
                // Map needs a fixed container, not a ScrollView
                if state.isLoadingTab {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MapTab().padding(12)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if state.isLoadingTab {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            tabContent
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 22)
                }
            }
        }
        .background(colors.bgWindow)
        .onChange(of: state.activeTab) { _, newTab in
            Task { await state.loadTabData(for: newTab) }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.activeTab {
        case .discover:
            DiscoverTab()
        case .favorites:
            FavoritesTab()
        case .search:
            SearchTab()
        case .topVoted:
            RankedTab(sortBy: .votes)
        case .popular:
            RankedTab(sortBy: .clicks)
        case .countries:
            CountriesTab()
        case .map:
            MapTab()
        case .history:
            HistoryTab()
        }
    }
}
