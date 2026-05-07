import SwiftUI
import RadioBrowserKit

struct StationRow: View {
    let station: Station
    let index: Int
    let isPlaying: Bool
    var showRank: Bool = false
    var rankNumber: Int = 0
    var showDuration: String? = nil
    var timeLabel: String? = nil

    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var isHovered = false

    var body: some View {
        let (c1, c2) = station.gradientColors

        HStack(spacing: AppLayout.rowGap) {
            Group {
                if let time = timeLabel {
                    Text(time)
                        .font(.system(size: 10.5, design: .monospaced))
                } else if showRank {
                    Text("\(rankNumber)")
                        .font(Typography.mono)
                } else if isPlaying {
                    Text("♪")
                        .font(Typography.mono)
                        .foregroundStyle(colors.accent.strong)
                } else {
                    Text("\(index + 1)")
                        .font(Typography.mono)
                }
            }
            .foregroundStyle(isPlaying ? colors.accent.strong : colors.fg3)
            .frame(width: AppLayout.rowNumWidth, alignment: .trailing)
            .monospacedDigit()

            // Cover
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [c1, c2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: AppLayout.coverSize, height: AppLayout.coverSize)
                .overlay(
                    Text(station.glyph)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.system(size: 13, weight: isPlaying ? .semibold : .medium))
                    .foregroundStyle(isPlaying ? colors.accent.strong : colors.fg)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(station.countryFlag)
                        .font(.system(size: 12))
                    Text(station.countryName)
                        .font(Typography.meta)
                        .foregroundStyle(colors.fg3)

                    Circle()
                        .fill(colors.fg4)
                        .frame(width: 2, height: 2)

                    if let showDuration {
                        Text("Played for \(showDuration)")
                            .font(Typography.meta)
                            .foregroundStyle(colors.fg3)
                    } else {
                        HStack(spacing: 0) {
                            if let codec = station.codecDisplay {
                                Text(codec)
                            }
                            if let br = station.bitrateFormatted {
                                Text(" \(br)")
                            }
                        }
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(colors.fg3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Tags (first 2)
            HStack(spacing: 4) {
                ForEach(station.tagList.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(colors.fg2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1.5)
                        .background(colors.bgPill)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: 220, alignment: .leading)

            // Votes
            HStack(spacing: 4) {
                Image(systemName: "star")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.fg3)
                Text(station.votesFormatted)
                    .font(Typography.monoSm)
                    .foregroundStyle(colors.fg3)
                    .monospacedDigit()
            }

            // Actions (visible on hover)
            HStack(spacing: 2) {
                RowActionButton(icon: "play.fill", size: 13)
                RowActionButton(
                    icon: state.isFavorite(station) ? "star.fill" : "star",
                    size: 13,
                    color: state.isFavorite(station) ? colors.statusWarn : nil
                ) {
                    state.toggleFavorite(station)
                }
                RowActionButton(icon: "ellipsis", size: 13)
            }
            .opacity(isHovered || state.isFavorite(station) ? 1 : 0)
        }
        .padding(.vertical, AppLayout.rowPaddingV)
        .padding(.horizontal, AppLayout.rowPaddingH)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.rSm)
                .fill(isPlaying ? colors.accent.soft : (isHovered ? colors.bgHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { state.play(station) }
    }
}

private struct RowActionButton: View {
    let icon: String
    let size: CGFloat
    var color: Color? = nil
    var action: (() -> Void)? = nil
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(color ?? (hovered ? colors.fg : colors.fg3))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered ? colors.bgActive : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
