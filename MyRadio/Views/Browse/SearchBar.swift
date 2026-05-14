import SwiftUI

struct SearchBar: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Search field
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 32)

                @Bindable var s = state
                TextField("Search stations…", text: $s.searchQuery)
                    .font(Typography.searchInput)
                    .foregroundStyle(colors.fg)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onChange(of: state.searchFocusRequest) { _, _ in
                        isFocused = true
                    }
            }
            .frame(height: 32)
            .background(colors.bgInput)
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .strokeBorder(colors.borderStrong, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))

            // Add station button
            Button { state.showAddStation = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add station")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(colors.accent.fg)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(colors.accent.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.rSm)
                        .strokeBorder(colors.accent.strong, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.border)
                .frame(height: 0.5)
        }
    }
}
