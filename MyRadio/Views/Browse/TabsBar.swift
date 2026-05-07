import SwiftUI

struct TabsBar: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(TabKind.allCases) { tab in
                    TabButton(tab: tab)
                }
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.border)
                .frame(height: 0.5)
        }
    }
}

private struct TabButton: View {
    let tab: TabKind
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    private var isActive: Bool { state.activeTab == tab }

    private var count: String? {
        switch tab {
        case .favorites:
            let c = state.favorites.count
            return c > 0 ? "\(c)" : nil
        case .history:
            let c = state.history.count
            return c > 0 ? "\(c)" : nil
        default:
            return nil
        }
    }

    var body: some View {
        Button {
            state.activeTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 11))
                Text(tab.label)
                    .font(.system(size: 12.5, weight: .medium))

                if let count {
                    Text(count)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive ? colors.accent.soft : colors.bgPill)
                        )
                        .foregroundStyle(isActive ? colors.accent.strong : colors.fg3)
                }
            }
            .foregroundStyle(isActive ? colors.fg : (hovered ? colors.fg : colors.fg2))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                if isActive {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.accent.strong)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                        .offset(y: 0.25)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
