import SwiftUI
import AVFoundation

struct TrackInfoSheet: View {
    let stationName: String
    let tracks: [iTunesTrack]
    let onDismiss: () -> Void

    @State private var selectedIndex = 0
    @State private var artworks: [Int: NSImage] = [:]
    @State private var previewPlayer: AVPlayer?
    @State private var isPreviewPlaying = false
    @Environment(\.appColors) private var colors

    private var track: iTunesTrack { tracks[selectedIndex] }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider()

                ScrollView {
                    HStack(alignment: .top, spacing: 28) {
                        artwork
                        info
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 820, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
        .task { await loadArtworks() }
        .onDisappear { stopPreview() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // NOW ON AIR pill
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: 0xFF4040))
                    .frame(width: 7, height: 7)
                Text("NOW ON AIR · \(stationName.uppercased())")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.fg)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colors.bgPill)
            .clipShape(Capsule())

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 28, height: 28)
                    .background(colors.bgPill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
            if let img = artworks[track.id] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MATCHED ON ITUNES")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(colors.accent.strong)
                .tracking(0.6)
                .padding(.bottom, 8)

            Text(track.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(colors.fg)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            Text(track.artist)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(colors.fg)
                .padding(.bottom, 3)

            HStack(spacing: 4) {
                Text("from")
                    .foregroundStyle(colors.fg3)
                Text(track.album)
                    .foregroundStyle(colors.fg2)
                if let y = track.year {
                    Text("· \(y)")
                        .foregroundStyle(colors.fg3)
                }
            }
            .font(.system(size: 13))
            .padding(.bottom, 16)

            // Metadata grid
            HStack(spacing: 20) {
                metaCell(label: "GENRE",   value: track.genre ?? "—")
                if let dur = track.duration {
                    metaCell(label: "LENGTH", value: dur)
                }
                metaCell(label: "COUNTRY", value: track.country ?? "—")
                if let p = track.price, let c = track.currency, p > 0 {
                    let sym = Locale(identifier: "en_US@currency=\(c)").currencySymbol ?? "$"
                    metaCell(label: "ITUNES", value: String(format: "\(sym)%.2f", p))
                }
            }
            .padding(.bottom, 16)

            Divider().padding(.bottom, 16)

            // Action buttons
            HStack(spacing: 10) {
                previewButton
                linkButton(label: "Apple Music",   icon: "apple.logo",  color: .pink,   url: track.trackViewURL)
                linkButton(label: "Spotify",        icon: "music.note",  color: .green,  url: spotifyURL)
                linkButton(label: "YouTube Music",  icon: "play.fill",   color: .red,    url: ytMusicURL)
            }
            .padding(.bottom, 16)

            // Matches list
            if tracks.count > 1 {
                matchesList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Meta cell

    private func metaCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(colors.fg3)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colors.fg)
        }
    }

    // MARK: - Preview button

    private var previewButton: some View {
        Button {
            togglePreview()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPreviewPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 11))
                Text(isPreviewPlaying ? "Stop" : "Preview 30s")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(track.previewURL != nil ? colors.accent.fg : colors.fg3)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(track.previewURL != nil ? colors.accent.accent : colors.bgPill)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(track.previewURL == nil)
    }

    private func linkButton(label: String, icon: String, color: Color, url: String?) -> some View {
        Button {
            guard let s = url, let u = URL(string: s) else { return }
            NSWorkspace.shared.open(u)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(url != nil ? colors.fg : colors.fg3)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colors.bgElevated)
            .overlay(
                Capsule().strokeBorder(colors.border, lineWidth: 0.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(url != nil ? 1 : 0.4)
        .disabled(url == nil)
    }

    // MARK: - Matches list

    private var matchesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(tracks.count) MATCHES · PICK THE RIGHT ONE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(colors.accent.strong)
                .tracking(0.5)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, t in
                        matchRow(t, index: idx)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func matchRow(_ t: iTunesTrack, index: Int) -> some View {
        let selected = index == selectedIndex
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedIndex = index }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    if let img = artworks[t.id] {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.fg)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(t.album)
                        Text("·")
                        Text(t.year.map(String.init) ?? "")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(colors.fg3)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? colors.accent.soft : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Links

    private var spotifyURL: String? {
        let q = "\(track.artist) \(track.title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://open.spotify.com/search/\(q)"
    }

    private var ytMusicURL: String? {
        let q = "\(track.artist) \(track.title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://music.youtube.com/search?q=\(q)"
    }

    // MARK: - Artwork loading

    private func loadArtworks() async {
        for t in tracks {
            guard let urlStr = t.artworkURL, let url = URL(string: urlStr) else { continue }
            if let img = await iTunesArtworkService.shared.image(from: url) {
                artworks[t.id] = img
            }
        }
    }

    // MARK: - Preview playback

    private func togglePreview() {
        if isPreviewPlaying {
            stopPreview()
        } else {
            guard let urlStr = track.previewURL, let url = URL(string: urlStr) else { return }
            previewPlayer = AVPlayer(url: url)
            previewPlayer?.play()
            isPreviewPlaying = true
            Task {
                try? await Task.sleep(nanoseconds: 31_000_000_000)
                stopPreview()
            }
        }
    }

    private func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
        isPreviewPlaying = false
    }
}
