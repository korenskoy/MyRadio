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
    private(set) var audioLevels: [Float] = Array(repeating: 0, count: 36)

    var volume: Float = 0.65 {
        didSet { player?.volume = volume }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var log: DebugLog?

    private var currentURL: URL?
    private var isReconnecting = false
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private let reconnectBaseDelay: TimeInterval = 2

    private var levelTimer: Timer?
    private var phase: Double = 0

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
        stopLevelSimulation()
        teardownPlayer()
        currentURL = nil
        reconnectCount = 0
        dataReceived = 0
        latency = 0
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            stopLevelSimulation()
        } else {
            player.play()
            isPlaying = true
            startLevelSimulation()
        }
    }

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
        startLevelSimulation()
        log?.append(.info, "Stream connected", source: "audio.player")
    }

    private func teardownPlayer() {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil
        statusObservation?.invalidate()
        rateObservation?.invalidate()
        statusObservation = nil
        rateObservation = nil

        if let output = metadataOutput, let item = playerItem {
            item.remove(output)
        }
        metadataOutput = nil

        player?.pause()
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
        stopLevelSimulation()

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

                if self.isPlaying {
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

        statusObservation = item.observe(\.status) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .failed:
                self.log?.append(.error, "Stream failed: \(item.error?.localizedDescription ?? "unknown")", source: "audio.player")
                self.handleStreamFailure()
            case .readyToPlay:
                self.log?.append(.debug, "Stream ready to play", source: "audio.player")
                self.updateAccessLog()
            default:
                break
            }
        }
    }

    private func observePlayer() {
        guard let player else { return }

        rateObservation = player.observe(\.rate) { [weak self] player, _ in
            guard let self else { return }
            let playing = player.rate > 0
            self.isPlaying = playing
            if playing {
                self.startLevelSimulation()
            } else if !self.isReconnecting {
                self.stopLevelSimulation()
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

    // MARK: - Audio level simulation

    private func startLevelSimulation() {
        guard levelTimer == nil else { return }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            self?.updateLevels()
        }
    }

    private func stopLevelSimulation() {
        levelTimer?.invalidate()
        levelTimer = nil
        withAnimation(.easeOut(duration: 0.4)) {
            audioLevels = Array(repeating: 0, count: 36)
        }
    }

    private func updateLevels() {
        phase += 0.15
        var newLevels = [Float](repeating: 0, count: 36)
        for i in 0..<36 {
            let fi = Float(i)
            let base = 0.3 + 0.4 * sin(Float(phase) * 0.7 + fi * 0.3)
            let wave = 0.2 * sin(Float(phase) * 1.3 + fi * 0.5)
            let noise = Float.random(in: -0.15...0.15)
            newLevels[i] = max(0.05, min(1.0, base + wave + noise))
        }
        audioLevels = newLevels
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
