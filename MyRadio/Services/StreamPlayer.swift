import AVFoundation
import SwiftUI

@Observable
final class StreamPlayer: NSObject {
    private(set) var isPlaying = false
    private(set) var nowPlayingTitle: String?
    private(set) var icyMetadata: [String: String] = [:]
    private(set) var bufferHealth: TimeInterval = 0
    private(set) var currentBitrate: Double = 0
    private(set) var dataReceived: Int64 = 0
    private(set) var reconnectCount: Int = 0
    private(set) var latency: TimeInterval = 0

    var volume: Float = 0.65 {
        didSet { player?.volume = volume }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var log: DebugLog?

    private var currentURL: URL?
    private var isReconnecting = false
    private var reconnectTask: Task<Void, Never>?
    private var stallWatchdog: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private let reconnectBaseDelay: TimeInterval = 2
    /// How long playback may sit in `.waitingToPlayAtSpecifiedRate` before we
    /// treat it as a dead stream and force a reconnect.
    private let stallTimeout: TimeInterval = 12

    func configure(log: DebugLog) {
        self.log = log
    }

    func play(url: URL) {
        stop()
        currentURL = url
        reconnectCount = 0
        dataReceived = 0
        startStream(url: url)
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        teardownPlayer()
        currentURL = nil
        reconnectCount = 0
        dataReceived = 0
        latency = 0
    }

    /// True once a stream has been loaded into the player (i.e. `play(url:)` ran
    /// and `stop()` hasn't since cleared it). Lets callers tell "paused" apart
    /// from "never started", so play can start a fresh stream instead of no-op'ing.
    var isLoaded: Bool { player != nil }

    // MARK: - Stream lifecycle

    private func startStream(url: URL) {
        log?.append(.info, "Loading stream: \(url.absoluteString)", source: "audio.player")

        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        playerItem?.add(output)
        metadataOutput = output

        let p = AVPlayer(playerItem: playerItem)
        p.volume = volume
        player = p

        observePlayerItem()
        observePlayer()

        p.play()
        isPlaying = true
        log?.append(.info, "Stream connected", source: "audio.player")
    }

    private func teardownPlayer() {
        // Cancel observations before touching the player — avoids callbacks on dead objects.
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
        statusObservation = nil
        timeControlObservation = nil
        cancelStallWatchdog()

        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil

        // Detach metadata delegate so it can't fire after teardown.
        metadataOutput?.setDelegate(nil, queue: nil)
        if let output = metadataOutput, let item = playerItem { item.remove(output) }
        metadataOutput = nil

        // Explicit replaceCurrentItem before nil — lets AVFoundation close
        // internal NW connections cleanly instead of leaving them dangling.
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil

        isPlaying = false
        nowPlayingTitle = nil
        icyMetadata = [:]
        bufferHealth = 0
        currentBitrate = 0
        latency = 0
    }

    // MARK: - Reconnect

    private func handleStreamFailure() {
        guard !isReconnecting, let url = currentURL else { return }
        isReconnecting = true
        isPlaying = false

        reconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for attempt in 1...self.maxReconnectAttempts {
                guard !Task.isCancelled else { return }

                let delay = self.reconnectBaseDelay * pow(1.5, Double(attempt - 1))
                self.log?.append(.warn, "Reconnecting in \(String(format: "%.1f", delay))s (attempt \(attempt)/\(self.maxReconnectAttempts))", source: "audio.player")

                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }

                self.teardownPlayer()
                self.reconnectCount += 1
                self.startStream(url: url)

                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }

                // `isPlaying`/`rate` go true the instant we call play(), even on a
                // dead stream — only `timeControlStatus == .playing` means audio
                // is actually flowing.
                if self.player?.timeControlStatus == .playing {
                    self.log?.append(.info, "Reconnected successfully after \(attempt) attempt(s)", source: "audio.player")
                    self.isReconnecting = false
                    return
                }
            }

            self.log?.append(.error, "Failed to reconnect after \(self.maxReconnectAttempts) attempts", source: "audio.player")
            self.isReconnecting = false
        }
    }

    // MARK: - Observation

    private func observePlayerItem() {
        guard let item = playerItem else { return }

        // KVO callbacks arrive on an arbitrary AVFoundation queue; capture the
        // primitives and hop to the main actor before touching observable state.
        statusObservation = item.observe(\.status) { [weak self] item, _ in
            let status = item.status
            let error = item.error as NSError?
            Task { @MainActor [weak self] in
                self?.handleStatusChange(status, error: error)
            }
        }
    }

    @MainActor
    private func handleStatusChange(_ status: AVPlayerItem.Status, error: NSError?) {
        switch status {
        case .failed:
            // `.failed` is terminal for an AVPlayerItem — it never recovers on
            // its own, so always rebuild the item. (The transient-error class is
            // only used to pick the log level here.)
            let desc = error?.localizedDescription ?? "unknown"
            if error.map({ isMpegTransientError($0) }) ?? false {
                log?.append(.warn, "Stream failed (transient-class error) — reconnecting: \(desc)", source: "audio.player")
            } else {
                log?.append(.error, "Stream failed: \(desc)", source: "audio.player")
            }
            handleStreamFailure()
        case .readyToPlay:
            log?.append(.debug, "Stream ready to play", source: "audio.player")
            updateAccessLog()
        default:
            break
        }
    }

    private func observePlayer() {
        guard let player else { return }

        timeControlObservation = player.observe(\.timeControlStatus) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(status)
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 2, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            self?.updateBufferHealth()
            self?.updateAccessLog()
        }
    }

    @MainActor
    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            cancelStallWatchdog()
        case .waitingToPlayAtSpecifiedRate:
            // Buffering or stalled: we're still "trying", but arm a watchdog so a
            // stream that never delivers audio gets reconnected instead of
            // hanging silently with isPlaying == true.
            isPlaying = true
            startStallWatchdog()
        case .paused:
            isPlaying = false
            cancelStallWatchdog()
        @unknown default:
            break
        }
    }

    private func startStallWatchdog() {
        guard !isReconnecting else { return }
        stallWatchdog?.cancel()
        stallWatchdog = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.stallTimeout))
            guard !Task.isCancelled else { return }
            if self.player?.timeControlStatus != .playing, !self.isReconnecting {
                self.log?.append(.warn, "Playback stalled for \(Int(self.stallTimeout))s — forcing reconnect", source: "audio.player")
                self.handleStreamFailure()
            }
        }
    }

    private func cancelStallWatchdog() {
        stallWatchdog?.cancel()
        stallWatchdog = nil
    }

    // MARK: - Stream diagnostics

    private func updateBufferHealth() {
        guard let item = playerItem else { return }
        let ranges = item.loadedTimeRanges
        guard let range = ranges.first?.timeRangeValue else { return }
        let currentTime = item.currentTime()
        let bufferedEnd = CMTimeAdd(range.start, range.duration)
        bufferHealth = CMTimeGetSeconds(bufferedEnd) - CMTimeGetSeconds(currentTime)
    }

    private func updateAccessLog() {
        guard let accessLog = playerItem?.accessLog(),
              let event = accessLog.events.last else { return }
        currentBitrate = event.observedBitrate / 1000
        if event.numberOfBytesTransferred > 0 {
            dataReceived = event.numberOfBytesTransferred
        }
        if event.transferDuration > 0 {
            latency = event.transferDuration
        }
    }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension StreamPlayer: AVPlayerItemMetadataOutputPushDelegate {
    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        for group in groups {
            for item in group.items {
                guard let key = item.commonKey?.rawValue ?? item.key as? String,
                      let value = item.value as? String
                else { continue }

                icyMetadata[key] = value

                if key == "title" || key.lowercased().contains("streamtitle") {
                    nowPlayingTitle = value
                    log?.append(.info, "ICY StreamTitle: \(value)", source: "icy.client")
                }
            }
        }
    }
}

// ICY metadata updates and HTTP range resets produce transient AVFoundation
// errors that look fatal but aren't — the stream recovers on its own.
// Codes: -12640 ICY pump, -12860/-12783 FigStreamPlayer, -12539 HTTP,
//        -12753 timebase reset, -15514 HLS segment.
private func isMpegTransientError(_ error: NSError) -> Bool {
    guard error.domain == "CoreMediaErrorDomain" else { return false }
    let transient: Set<Int> = [-12640, -12860, -12783, -12539, -12540, -12753, -15514]
    return transient.contains(error.code)
}
