import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Voice catalog

struct VoiceOption: Identifiable {
    let id: String
    let name: String
    let language: String
    let quality: AVSpeechSynthesisVoiceQuality

    var qualityLabel: String {
        switch quality {
        case .premium: return "高级"
        case .enhanced: return "增强"
        default: return "标准"
        }
    }

    var languageLabel: String {
        if language.hasPrefix("zh-CN") { return "普通话" }
        if language.hasPrefix("zh-TW") { return "台湾" }
        if language.hasPrefix("zh-HK") { return "粤语" }
        return language
    }

    var isHighQuality: Bool { quality != .default }
}

enum VoiceCatalog {
    static func chineseVoices() -> [VoiceOption] {
        let options = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") }
            .map {
                VoiceOption(
                    id: $0.identifier,
                    name: $0.name,
                    language: $0.language,
                    quality: $0.quality
                )
            }

        let unique = Dictionary(grouping: options, by: \.id)
            .compactMap { $0.value.first }

        return unique.sorted { lhs, rhs in
            if lhs.language != rhs.language { return lhs.language < rhs.language }
            if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
            return lhs.name < rhs.name
        }
    }

    static func defaultIdentifier() -> String? {
        chineseVoices().first?.id
            ?? AVSpeechSynthesisVoice(language: "zh-CN")?.identifier
    }

    static func voice(for identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        if let identifier = defaultIdentifier() {
            return AVSpeechSynthesisVoice(identifier: identifier)
        }
        return AVSpeechSynthesisVoice(language: "zh-CN")
    }
}

// MARK: - Playback state

enum PlaybackState: String, Equatable {
    case idle
    case playing
    case paused
    case finished

    var isActive: Bool { self == .playing || self == .paused }
}

// MARK: - Player

final class SpeechPlayer: NSObject, ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var chunkIndex: Int = 0
    @Published private(set) var sentenceIndex: Int = 0
    @Published private(set) var currentSentence: ReaderSentence?
    @Published private(set) var sentenceCount: Int = 0
    @Published private(set) var errorMessage: String?

    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Keys.speed) }
    }

    @Published var emotionMode: Emotion {
        didSet { defaults.set(emotionMode.rawValue, forKey: Keys.emotion) }
    }

    @Published var voiceIdentifier: String? {
        didSet { defaults.set(voiceIdentifier, forKey: Keys.voice) }
    }

    @Published var autoScroll: Bool {
        didSet { defaults.set(autoScroll, forKey: Keys.autoScroll) }
    }

    var onProgress: ((_ sentenceIndex: Int, _ charOffset: Int, _ progress: Double) -> Void)?
    var onFinished: (() -> Void)?

    private enum Keys {
        static let speed = "reader.speed"
        static let emotion = "reader.emotion"
        static let voice = "reader.voice"
        static let autoScroll = "reader.autoScroll"
    }

    private let defaults = UserDefaults.standard
    private let synthesizer = AVSpeechSynthesizer()
    private var chunks: [SpeechChunk] = []
    private var sentences: [ReaderSentence] = []
    private var currentUtterance: AVSpeechUtterance?
    private var advanceWorkItem: DispatchWorkItem?
    private var pendingPause = false
    private var resumeAfterInterruption = false
    private var didConfigureSession = false
    private var bookTitle = ""
    private var bookAuthor = ""
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    override init() {
        let defaults = UserDefaults.standard
        speed = defaults.object(forKey: Keys.speed) as? Double ?? 1.0
        emotionMode = Emotion(rawValue: defaults.string(forKey: Keys.emotion) ?? "") ?? .auto
        voiceIdentifier = defaults.string(forKey: Keys.voice)
        autoScroll = defaults.object(forKey: Keys.autoScroll) as? Bool ?? true
        super.init()
        synthesizer.delegate = self
        observeAudioSession()
        configureRemoteCommands()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Public state

    var currentEmotion: Emotion {
        guard let currentSentence else {
            return emotionMode == .auto ? .calm : emotionMode
        }
        return EmotionDirector.resolve(emotionMode, for: currentSentence.text)
    }

    var progress: Double {
        guard sentenceCount > 0 else { return 0 }
        return min(1, max(0, Double(sentenceIndex + 1) / Double(sentenceCount)))
    }

    var speedLabel: String {
        let value = (speed * 100).rounded() / 100
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.1f×", value)
        }
        return String(format: "%.2f×", value)
    }

    // MARK: - Loading

    func load(
        title: String,
        author: String,
        sentences: [ReaderSentence],
        chunks: [SpeechChunk],
        startSentenceIndex: Int
    ) {
        cancelAdvance()
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        self.bookTitle = title
        self.bookAuthor = author
        self.sentences = sentences
        self.chunks = chunks
        sentenceCount = sentences.count
        currentSentence = nil

        let target = max(0, min(startSentenceIndex, max(0, sentences.count - 1)))
        chunkIndex = chunks.firstIndex(where: { $0.sentenceIndex >= target }) ?? 0
        state = .idle
        updateCurrentSentence()
        updateNowPlaying()
    }

    // MARK: - Transport

    func toggle() {
        switch state {
        case .playing:
            pause()
        case .paused:
            play()
        case .idle, .finished:
            play()
        }
    }

    func play() {
        guard !chunks.isEmpty else { return }

        if state == .paused, advanceWorkItem == nil {
            if synthesizer.continueSpeaking() {
                state = .playing
                updateNowPlaying()
                return
            }
        }

        if state == .finished || chunkIndex >= chunks.count {
            chunkIndex = 0
            updateCurrentSentence()
        }
        speakCurrentChunk()
    }

    func pause() {
        guard state == .playing else { return }

        if advanceWorkItem != nil {
            // 正停在两句之间的换气处：把位置推进到下一句，恢复时不会重复上一句。
            cancelAdvance()
            if chunkIndex + 1 < chunks.count {
                chunkIndex += 1
                updateCurrentSentence()
            }
            state = .paused
            notifyProgress()
            updateNowPlaying()
            return
        }

        if synthesizer.pauseSpeaking(at: .immediate) {
            state = .paused
            notifyProgress()
            updateNowPlaying()
        } else {
            // 有时第一帧还没真正开始发声，等 didStart 再暂停。
            pendingPause = true
        }
    }

    func stop() {
        cancelAdvance()
        currentUtterance = nil
        pendingPause = false
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        updateNowPlaying()
    }

    func end() {
        stop()
        deactivateSession()
    }

    func seek(toSentence index: Int, autoplay: Bool = true) {
        guard let target = chunks.firstIndex(where: { $0.sentenceIndex >= index }) else { return }
        cancelAdvance()
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        pendingPause = false
        chunkIndex = target
        updateCurrentSentence()
        notifyProgress()

        if autoplay {
            speakCurrentChunk()
        } else {
            state = .idle
            updateNowPlaying()
        }
    }

    func nextSentence() {
        guard let current = chunks[safe: chunkIndex]?.sentenceIndex else { return }
        guard let target = chunks.first(where: { $0.sentenceIndex > current && $0.isSentenceStart }) else {
            return
        }
        seek(toSentence: target.sentenceIndex)
    }

    func previousSentence() {
        guard let current = chunks[safe: chunkIndex]?.sentenceIndex else { return }
        if let first = chunks.firstIndex(where: { $0.sentenceIndex == current && $0.isSentenceStart }),
           chunkIndex > first {
            seek(toSentence: current)
            return
        }
        if let previous = chunks.last(where: { $0.sentenceIndex < current && $0.isSentenceStart }) {
            seek(toSentence: previous.sentenceIndex)
        } else {
            seek(toSentence: 0)
        }
    }

    func repeatSentence() {
        guard let current = chunks[safe: chunkIndex]?.sentenceIndex else { return }
        seek(toSentence: current)
    }

    // MARK: - Speaking

    private func speakCurrentChunk() {
        guard chunks.indices.contains(chunkIndex) else { return }
        let chunk = chunks[chunkIndex]
        let sentenceText = sentences.first { $0.id == chunk.sentenceIndex }?.text ?? chunk.text
        let emotion = EmotionDirector.resolve(emotionMode, for: sentenceText)

        ensureAudioSession()

        let utterance = AVSpeechUtterance(string: chunk.text)
        utterance.voice = VoiceCatalog.voice(for: voiceIdentifier)
        utterance.rate = Float(min(max(0.46 * speed * emotion.rateFactor, 0.20), 0.75))
        utterance.pitchMultiplier = Float(emotion.pitch)
        utterance.volume = Float(emotion.volume)
        utterance.preUtteranceDelay = 0.02
        utterance.postUtteranceDelay = 0

        currentUtterance = utterance
        pendingPause = false
        updateCurrentSentence()
        state = .playing
        synthesizer.speak(utterance)
        notifyProgress()
        updateNowPlaying()
    }

    private func scheduleAdvance(after delay: TimeInterval) {
        cancelAdvance()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.advanceWorkItem = nil
            guard self.state == .playing else { return }
            if self.chunkIndex + 1 < self.chunks.count {
                self.chunkIndex += 1
                self.updateCurrentSentence()
                self.speakCurrentChunk()
            } else {
                self.finishPlayback()
            }
        }
        advanceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelAdvance() {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
    }

    private func finishPlayback() {
        cancelAdvance()
        currentUtterance = nil
        state = .finished
        notifyProgress()
        updateNowPlaying()
        onFinished?()
        deactivateSession()
    }

    private func updateCurrentSentence() {
        guard chunks.indices.contains(chunkIndex) else { return }
        let newIndex = chunks[chunkIndex].sentenceIndex
        if sentenceIndex != newIndex {
            sentenceIndex = newIndex
        }
        if currentSentence?.id != newIndex {
            currentSentence = sentences.first { $0.id == newIndex }
        }
    }

    private func notifyProgress() {
        guard chunks.indices.contains(chunkIndex), currentSentence != nil else { return }
        let value = Double(sentenceIndex + 1) / Double(max(sentenceCount, 1))
        onProgress?(
            sentenceIndex,
            chunks[chunkIndex].range.location,
            min(1, max(0, value))
        )
    }

    // MARK: - Audio session

    private func ensureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if !didConfigureSession {
                try session.setCategory(.playback, mode: .spokenAudio, options: [])
                didConfigureSession = true
            }
            try session.setActive(true)
            errorMessage = nil
        } catch {
            errorMessage = "无法启用音频：\(error.localizedDescription)"
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }

    private func observeAudioSession() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

            switch type {
            case .began:
                if self.state == .playing {
                    self.resumeAfterInterruption = true
                    self.pause()
                }
            case .ended:
                let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                if self.resumeAfterInterruption, options.contains(.shouldResume) {
                    self.resumeAfterInterruption = false
                    self.speakCurrentChunk()
                }
            @unknown default:
                break
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            if reason == .oldDeviceUnavailable, self.state == .playing {
                self.pause()
            }
        }
    }

    // MARK: - Remote controls

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.nextSentence() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.previousSentence() }
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = bookTitle.isEmpty ? "声笺" : bookTitle
        info[MPMediaItemPropertyArtist] = bookAuthor.isEmpty ? "声笺 · 情绪朗读" : bookAuthor
        info[MPMediaItemPropertyAlbumTitle] = "声笺 · 情绪朗读"
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechPlayer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        state = .playing
        if pendingPause {
            pendingPause = false
            if synthesizer.pauseSpeaking(at: .immediate) {
                state = .paused
            }
        }
        updateNowPlaying()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
        guard state == .playing else { return }
        let delay = currentEmotion.postDelay
        scheduleAdvance(after: delay)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        state = .paused
        updateNowPlaying()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        state = .playing
        updateNowPlaying()
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
