import Foundation
import MediaPlayer
import AppKit
import RadioBrowserKit

/// Keeps macOS Now Playing (Control Center, media keys, AirPods) in sync with the app state.
@MainActor
final class NowPlayingController {
    private let state: AppState

    init(state: AppState) {
        self.state = state
        setupRemoteCommands()
        observe()
    }

    // MARK: - Remote commands (media keys, AirPods, etc.)

    private func setupRemoteCommands() {
        let rc = MPRemoteCommandCenter.shared()

        rc.playCommand.isEnabled = true
        rc.pauseCommand.isEnabled = true
        rc.togglePlayPauseCommand.isEnabled = true
        rc.stopCommand.isEnabled = true
        rc.nextTrackCommand.isEnabled = false
        rc.previousTrackCommand.isEnabled = false

        rc.playCommand.addTarget  { [weak self] _ in self?.state.togglePlayPause(); return .success }
        rc.pauseCommand.addTarget { [weak self] _ in self?.state.togglePlayPause(); return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in self?.state.togglePlayPause(); return .success }
        rc.stopCommand.addTarget  { [weak self] _ in self?.state.stopPlayback();    return .success }
    }

    // MARK: - Observation loop

    private func observe() {
        withObservationTracking {
            update()
        } onChange: {
            Task { @MainActor in self.observe() }
        }
    }

    // MARK: - Info update

    private func update() {
        guard let station = state.currentStation else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPNowPlayingInfoPropertyIsLiveStream:          true,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:   0,
            MPNowPlayingInfoPropertyPlaybackRate:          state.isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyAlbumTitle:                 station.name,
        ]

        // Parse "Artist - Track" from ICY StreamTitle
        if let raw = state.nowPlayingTitle, !raw.isEmpty {
            let parts = raw.components(separatedBy: " - ")
            if parts.count >= 2 {
                info[MPMediaItemPropertyArtist] = parts[0].trimmingCharacters(in: .whitespaces)
                info[MPMediaItemPropertyTitle]  = parts.dropFirst().joined(separator: " - ")
                    .trimmingCharacters(in: .whitespaces)
            } else {
                info[MPMediaItemPropertyTitle]  = raw
                info[MPMediaItemPropertyArtist] = station.name
            }
        } else {
            info[MPMediaItemPropertyTitle]  = station.name
            info[MPMediaItemPropertyArtist] = "Live"
        }

        MPNowPlayingInfoCenter.default().playbackState = state.isPlaying ? .playing : .paused

        // Artwork: prefer iTunes track art (synced from NowPlayingView); fall back to station favicon.
        // Access currentTrackArtwork synchronously so withObservationTracking re-fires on changes.
        if let trackImg = state.currentTrackArtwork {
            var patched = info
            patched[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: trackImg.size) { _ in trackImg }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = patched
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            let uuid    = station.stationuuid
            let favicon = station.favicon
            Task { @MainActor in
                guard let nsImage = await ArtworkCache.shared.image(for: uuid, faviconURL: favicon) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                var patched = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                patched[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = patched
            }
        }
    }
}
