import SwiftUI

struct MapTab: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 16) {
            ToolbarRow {
                BrowseButton(label: "Show all", icon: "map", style: .primary)
                BrowseButton(label: "Cluster")
                BrowseButton(label: "Heatmap")
                Spacer()
                BrowseButton(label: "", icon: "arrow.up.left.and.arrow.down.right", style: .ghost)
            }

            // Map placeholder
            RoundedRectangle(cornerRadius: AppLayout.rMd)
                .fill(colors.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.rMd)
                        .strokeBorder(colors.border, lineWidth: 0.5)
                )
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundStyle(colors.fg3)
                        Text("World map")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(colors.fg3)
                        Text("Interactive map will be implemented in Stage 5")
                            .font(Typography.meta)
                            .foregroundStyle(colors.fg4)
                    }
                )
                .aspectRatio(2, contentMode: .fit)
        }
    }
}
