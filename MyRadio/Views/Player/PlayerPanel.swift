import SwiftUI
import RadioBrowserKit

struct PlayerPanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.bgPanel, colors.bgPanel2],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                CoverArtView()
                StationMetaView()
                NowPlayingView()
                VisualizerView()
                Spacer(minLength: 0)
                TransportView()
            }
            .padding(.horizontal, AppLayout.playerPaddingH)
            .padding(.top, AppLayout.playerPaddingT)
            .padding(.bottom, AppLayout.playerPaddingB)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(colors.border)
                .frame(width: 0.5)
        }
    }
}

// MARK: - Cover Art

private struct CoverArtView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        let station = state.currentStation
        let (c1, c2) = station?.gradientColors ?? (Color.gray, Color.black)

        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.rLg)
                .fill(
                    LinearGradient(
                        colors: [c1, c2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 16)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)

            Text(station?.glyph ?? "♪")
                .font(.system(size: 96, weight: .heavy, design: .default))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                .tracking(-3)

            // LIVE pill
            VStack {
                HStack {
                    LivePill()
                    Spacer()
                    QualityBadge()
                }
                .padding(14)
                Spacer()
                HStack {
                    Spacer()
                    FavoriteOverlay()
                }
                .padding(12)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.rLg))
    }
}

private struct LivePill: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if state.isPlaying {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: 0xFF4040))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hex: 0xFF4040), radius: 3)
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.6)
            }
            .padding(.vertical, 4)
            .padding(.leading, 8)
            .padding(.trailing, 9)
            .background(.black.opacity(0.4))
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(Capsule())
        }
    }
}

private struct QualityBadge: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let station = state.currentStation {
            HStack(spacing: 0) {
                if let codec = station.codecDisplay {
                    Text(codec)
                }
                if let br = station.bitrateFormatted {
                    if station.codecDisplay != nil { Text(" · ") }
                    Text(br)
                }
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.black.opacity(0.35))
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }
}

private struct FavoriteOverlay: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        if let station = state.currentStation {
            Button {
                state.toggleFavorite(station)
            } label: {
                Image(systemName: state.isFavorite(station) ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xDBC850))
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.5))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Station Meta

private struct StationMetaView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        if let station = state.currentStation {
            VStack(alignment: .leading, spacing: 0) {
                Text(station.name)
                    .font(Typography.stationName)
                    .foregroundStyle(colors.fg)
                    .tracking(-0.5)
                    .lineLimit(1)
                    .padding(.bottom, 6)

                // Country · language · votes
                HStack(spacing: 8) {
                    Text(station.countryFlag)
                        .font(.system(size: 14))
                    Text(station.countryName)
                        .font(.system(size: 12))
                        .foregroundStyle(colors.fg2)
                    Text("·")
                        .foregroundStyle(colors.fg4)
                    Text(station.language ?? "—")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.fg2)
                    Text("·")
                        .foregroundStyle(colors.fg4)
                    HStack(spacing: 2) {
                        Text(station.votesLocalized)
                            .font(.system(size: 12))
                            .foregroundStyle(colors.fg2)
                        Text("★")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.fg2)
                    }
                }
                .padding(.top, 8)

                // Tags
                HStack(spacing: 6) {
                    ForEach(station.tagList.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(colors.fg2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(colors.bgPill)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 22)
        }
    }
}

// MARK: - Now Playing

private struct NowPlayingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            // Mini cover
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC45030), Color(hex: 0x6B1880)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text("MB\nart")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("NOW ON AIR")
                    .font(Typography.label)
                    .foregroundStyle(colors.accent.strong)
                    .tracking(0.8)

                Text(state.nowPlayingTitle ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 4) {
                NowPlayingActionButton(icon: "link", color: colors.fg3)
                NowPlayingActionButton(icon: "heart", color: colors.fg3)
            }
        }
        .padding(14)
        .background(colors.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.rMd)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.rMd))
        .padding(.top, 18)
    }
}

private struct NowPlayingActionButton: View {
    let icon: String
    let color: Color
    @Environment(\.appColors) private var colors

    var body: some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visualizer (36 static bars)

private struct VisualizerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    private let seed: [Double] = [
        0.3, 0.6, 0.9, 0.7, 0.4, 0.5, 0.85, 0.95, 0.6, 0.3, 0.45, 0.7,
        0.9, 0.65, 0.4, 0.3, 0.55, 0.75, 0.85, 0.7, 0.5, 0.4, 0.6, 0.8,
        0.92, 0.75, 0.55, 0.4, 0.3, 0.5, 0.65, 0.78, 0.88, 0.7, 0.5, 0.35
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<seed.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [colors.accent.strong, colors.accent.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: barHeight(i))
                    .opacity(state.isPlaying ? 0.85 : 0.3)
            }
        }
        .frame(height: 38)
        .padding(.horizontal, 2)
        .padding(.top, 14)
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let h = state.isPlaying ? seed[index] : 0.15
        return h * 38
    }
}

// MARK: - Transport (Play button + Volume + Utility bar)

private struct TransportView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 14) {
            // Play button row
            PlayButton()

            // Volume row
            VolumeRow()

            // Utility bar
            UtilityBar()
        }
        .padding(.top, 16)
    }
}

private struct PlayButton: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            state.togglePlayPause()
        } label: {
            let bgColor = scheme == .dark ? Color(hex: 0xF1EFE8) : colors.fg
            let fgColor = scheme == .dark ? Color(hex: 0x161614) : colors.bgWindow
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
                .foregroundStyle(fgColor)
                .frame(width: AppLayout.playButtonSize, height: AppLayout.playButtonSize)
                .background(bgColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct VolumeRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(colors.fg3)
                .frame(width: 14)

            VolumeSlider()

            Text("\(Int(state.volume * 100))")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fg3)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}

private struct VolumeSlider: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * state.volume

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.bgPill)
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.fg2)
                    .frame(width: fillWidth, height: 4)

                // Knob
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.1), radius: 0, x: 0, y: 0)
                    .overlay(
                        Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                    )
                    .offset(x: fillWidth - 6)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        state.volume = max(0, min(1, value.location.x / width))
                    }
            )
        }
        .frame(height: 12)
    }
}

// MARK: - Utility bar

private struct UtilityBar: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(colors.border)
                .frame(height: 0.5)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                UtilButton(icon: "slider.horizontal.3", label: "EQ", isActive: false)
                UtilButton(icon: "bed.double", label: "Sleep", isActive: false)
                UtilButton(icon: "arrow.down.right.and.arrow.up.left", label: "Mini", isActive: false)
                UtilButton(icon: "square.and.arrow.up", label: nil, isActive: false)
            }
        }
        .padding(.top, 12)
    }
}

private struct UtilButton: View {
    let icon: String
    let label: String?
    let isActive: Bool
    @Environment(\.appColors) private var colors

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                if let label {
                    Text(label)
                        .font(Typography.utility)
                }
            }
            .foregroundStyle(isActive ? colors.accent.strong : colors.fg2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .fill(isActive ? colors.accent.soft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .strokeBorder(isActive ? Color.clear : colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
