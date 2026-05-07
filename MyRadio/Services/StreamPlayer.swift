import AVFoundation

@Observable
final class StreamPlayer: NSObject {
    private(set) var isPlaying = false
    private(set) var nowPlayingTitle: String?
    private(set) var icyMetadata: [String: String] = [:]
    private(set) var bufferHealth: TimeInterval = 0
    private(set) var currentBitrate: Double = 0

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

    func configure(log: DebugLog) {
        self.log = log
    }

    func play(url: URL) {
        stop()
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

    func stop() {
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
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
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
                self.isPlaying = false
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
            self?.isPlaying = player.rate > 0
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
