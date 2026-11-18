import AVFoundation

/// Plays local files through `AVAudioEngine`: player → time/pitch → equaliser → main mixer.
///
/// Each play or seek schedules a fresh segment and bumps `generation`, so completion callbacks
/// from segments that were stopped or replaced are ignored.
@MainActor
final class LocalAudioEngine: AudioBackend {
    let engine = AVAudioEngine()
    let timePitch = AVAudioUnitTimePitch()
    let equalizer = AVAudioUnitEQ(numberOfBands: 10)
    private let player = AVAudioPlayerNode()

    private var file: AVAudioFile?
    private var connectedFormat: AVAudioFormat?
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var pausedTime: TimeInterval = 0
    private var generation = 0
    private var configurationObserver: (any NSObjectProtocol)?

    private(set) var isPlaying = false
    var onFinished: (@MainActor () -> Void)?

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        engine.attach(equalizer)
        for band in equalizer.bands {
            band.bypass = true
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        }
    }

    var hasLoadedItem: Bool { file != nil }

    var duration: TimeInterval {
        guard let file else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    var currentTime: TimeInterval {
        guard isPlaying, let file else { return pausedTime }
        var frame = segmentStartFrame
        if let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime) {
            frame += playerTime.sampleTime
        }
        return min(max(Double(frame) / file.processingFormat.sampleRate, 0), duration)
    }

    func load(_ url: URL) throws -> TimeInterval {
        let newFile = try AVAudioFile(forReading: url)
        invalidateSchedule()
        player.stop()
        isPlaying = false
        connect(for: newFile.processingFormat)
        file = newFile
        segmentStartFrame = 0
        pausedTime = 0
        return duration
    }

    func play() throws {
        guard file != nil, !isPlaying else { return }
        // Always reschedule from the paused position: interruptions and route changes can stop
        // the engine and drop what was scheduled.
        reschedule(at: pausedTime)
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        player.play()
        isPlaying = true
    }

    func pause() {
        guard isPlaying else { return }
        pausedTime = currentTime
        invalidateSchedule()
        player.pause()
        engine.pause()
        isPlaying = false
    }

    func stop() {
        invalidateSchedule()
        player.stop()
        engine.stop()
        file = nil
        isPlaying = false
        pausedTime = 0
        segmentStartFrame = 0
    }

    func seek(to time: TimeInterval) {
        guard file != nil else { return }
        let clamped = min(max(time, 0), duration)
        pausedTime = clamped
        if isPlaying {
            reschedule(at: clamped)
            player.play()
        }
    }

    // MARK: Scheduling

    private func connect(for format: AVAudioFormat) {
        if let connectedFormat,
           connectedFormat.sampleRate == format.sampleRate,
           connectedFormat.channelCount == format.channelCount {
            return
        }
        if engine.isRunning {
            engine.stop()
        }
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: equalizer, format: format)
        engine.connect(equalizer, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    private func reschedule(at time: TimeInterval) {
        guard let file else { return }
        let frame = min(AVAudioFramePosition(time * file.processingFormat.sampleRate), file.length)
        invalidateSchedule()
        player.stop()
        segmentStartFrame = frame
        let token = generation
        let remaining = file.length - frame
        guard remaining > 0 else {
            Task { [weak self] in self?.segmentFinished(token) }
            return
        }
        player.scheduleSegment(
            file,
            startingFrame: frame,
            frameCount: AVAudioFrameCount(remaining),
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.completionHandler(for: self, token: token)
        )
    }

    private func invalidateSchedule() {
        generation &+= 1
    }

    /// Built outside the main actor: AVFoundation calls it on an audio thread.
    nonisolated private static func completionHandler(
        for engine: LocalAudioEngine,
        token: Int
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak engine] _ in
            guard let engine else { return }
            Task { @MainActor in engine.segmentFinished(token) }
        }
    }

    private func segmentFinished(_ token: Int) {
        guard token == generation, file != nil else { return }
        isPlaying = false
        pausedTime = duration
        onFinished?()
    }

    private func handleConfigurationChange() {
        guard isPlaying else { return }
        let time = currentTime
        isPlaying = false
        pausedTime = time
        try? play()
    }
}
