import SwiftUI
import RadioBrowserKit

struct TagsTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    private var sortedTags: [NamedCount] {
        state.apiTags.sorted { $0.stationcount > $1.stationcount }
    }

    private var maxCount: Int { sortedTags.first?.stationcount ?? 1 }
    private var minCount: Int { sortedTags.last?.stationcount ?? 0 }

    private func fontSize(for count: Int) -> CGFloat {
        let t = Double(count - minCount) / max(1, Double(maxCount - minCount))
        return 11 + t * 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "\(state.apiTags.count) tags · sorted by station count") {
                Button {
                    state.selectedTag = nil
                    state.tagStations = []
                } label: {
                    Text("All")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(state.selectedTag == nil ? colors.accent.fg : colors.fg)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(state.selectedTag == nil ? colors.accent.accent : colors.bgInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppLayout.rSm)
                                .strokeBorder(state.selectedTag == nil ? colors.accent.strong : colors.borderStrong, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
                }
                .buttonStyle(.plain)

                if let tag = state.selectedTag {
                    TagActivePill(tag: tag) {
                        state.selectedTag = nil
                        state.tagStations = []
                    }
                }
            }

            if sortedTags.isEmpty {
                ContentUnavailableView("Loading tags…", systemImage: "tag")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(sortedTags) { tag in
                        TagChip(
                            name: tag.name,
                            count: tag.stationcount,
                            fontSize: fontSize(for: tag.stationcount),
                            isActive: state.selectedTag == tag.name
                        ) {
                            if state.selectedTag == tag.name {
                                state.selectedTag = nil
                                state.tagStations = []
                            } else {
                                Task { await state.loadStationsForTag(tag.name) }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)

                if state.selectedTag != nil {
                    StationListSection(
                        title: "Stations tagged #\(state.selectedTag!)",
                        subtitle: "\(state.tagStations.count) stations",
                        stations: state.tagStations
                    )
                }
            }
        }
    }
}

private struct TagChip: View {
    let name: String
    let count: Int
    let fontSize: CGFloat
    let isActive: Bool
    let action: () -> Void
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("#\(name)")
                    .font(.system(size: fontSize, weight: .medium))
                Text(count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(isActive ? colors.accent.fg.opacity(0.7) : colors.fg3)
                    .monospacedDigit()
            }
            .foregroundStyle(isActive ? colors.accent.fg : colors.fg)
            .padding(.horizontal, isActive ? 12 : 10)
            .padding(.vertical, isActive ? 6 : 4)
            .background(isActive ? colors.accent.accent : colors.bgPill)
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.rPill)
                    .strokeBorder(
                        isActive ? colors.accent.strong : (hovered ? colors.borderStrong : Color.clear),
                        lineWidth: 0.5
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct TagActivePill: View {
    let tag: String
    let onClose: () -> Void
    @Environment(\.appColors) private var colors

    var body: some View {
        Button(action: onClose) {
            HStack(spacing: 4) {
                Text(tag)
                Text("✕")
                    .font(.system(size: 9))
            }
            .font(.system(size: 12.5, weight: .medium))
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
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = layout(sizes: sizes, containerWidth: bounds.width)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                                  proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxH: CGFloat = 0
        var totalWidth: CGFloat = 0

        for size in sizes {
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += maxH + spacing
                maxH = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            maxH = max(maxH, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (offsets, CGSize(width: totalWidth, height: y + maxH))
    }
}
