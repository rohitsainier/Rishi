//
//  VADManager.swift
//  Rishi
//

import Foundation
import AVFoundation
import Combine

final class VADManager: NSObject {

    // MARK: - Configuration
    struct VADConfig {
        var silenceThreshold: Float = -40.0
        var speechThreshold: Float = -35.0
        var silenceDuration: TimeInterval = 3
        var minSpeechDuration: TimeInterval = 0.3
        var preSpeechBuffer: TimeInterval = 0.2
        var interruptThreshold: Float = -25.0   // PEAK dB threshold
    }

    // MARK: - Published State
    @Published var isSpeechDetected: Bool = false
    @Published var isListening: Bool = false
    @Published var currentAudioLevel: Float = -160.0
    @Published var isPaused: Bool = false

    // MARK: - Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onLoudSoundDetected: (() -> Void)?

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private var config: VADConfig

    private var silenceTimer: Timer?
    private var speechStartTime: Date?
    private var isSpeechActive = false

    // Interrupt handling
    private var isInterruptMonitoringMode = false
    private var lastInterruptTime: Date?
    private let interruptCooldown: TimeInterval = 0.5

    // MARK: - Initializer
    init(config: VADConfig = VADConfig()) {
        self.config = config
        super.init()
    }

    // MARK: - Public Methods
    func startMonitoring() {
        guard !audioEngine.isRunning else { return }

        setupAudioTap()

        do {
            try audioEngine.start()
            isListening = true
            isPaused = false
            print("✅ VAD monitoring started")
        } catch {
            print("❌ VAD failed to start: \(error.localizedDescription)")
        }
    }

    func stopMonitoring() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        silenceTimer?.invalidate()
        silenceTimer = nil

        isListening = false
        isPaused = false
        isSpeechDetected = false
        isSpeechActive = false
        speechStartTime = nil
        isInterruptMonitoringMode = false
        lastInterruptTime = nil

        print("🛑 VAD monitoring stopped")
    }

    func pauseMonitoring() {
        guard isListening else { return }

        isPaused = true
        isSpeechActive = false
        isSpeechDetected = false

        silenceTimer?.invalidate()
        silenceTimer = nil
        speechStartTime = nil

        print("⏸️ VAD paused (interrupt monitoring active)")
    }

    func resumeMonitoring() {
        guard isListening else { return }
        isPaused = false
        isInterruptMonitoringMode = false
        print("▶️ VAD resumed")
    }

    func enableInterruptMonitoring() {
        isInterruptMonitoringMode = true
        print("🎤 Interrupt monitoring enabled")
    }

    func disableInterruptMonitoring() {
        isInterruptMonitoringMode = false
    }

    func updateConfig(_ newConfig: VADConfig) {
        self.config = newConfig
    }

    // MARK: - Audio Setup
    private func setupAudioTap() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }

    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        var peak: Float = 0.0

        for i in 0..<frameLength {
            let sample = abs(channelDataValue[i])
            sum += sample * sample
            peak = max(peak, sample)
        }

        let rms = sqrt(sum / Float(frameLength))

        let rmsDB = max(-160.0, 20 * log10(rms))
        let peakDB = max(-160.0, 20 * log10(peak))

        DispatchQueue.main.async {
            self.currentAudioLevel = rmsDB
            self.onAudioLevel?(rmsDB)

            // 🔥 Interrupt detection uses PEAK
            if self.isInterruptMonitoringMode {
                self.checkForInterrupt(peakDB: peakDB)
            }

            // Normal VAD uses RMS
            if !self.isPaused {
                self.detectVoiceActivity(rmsDB: rmsDB)
            }
        }
    }

    // MARK: - Interrupt Detection (PEAK based)
    private func checkForInterrupt(peakDB: Float) {
        let now = Date()

        guard peakDB > config.interruptThreshold else { return }

        if let last = lastInterruptTime,
           now.timeIntervalSince(last) < interruptCooldown {
            return
        }

        lastInterruptTime = now
        print("🎤 Interrupt detected! Peak dB: \(peakDB)")
        onLoudSoundDetected?()
    }

    // MARK: - Voice Activity Detection (RMS based)
    private func detectVoiceActivity(rmsDB: Float) {
        if rmsDB > config.speechThreshold {
            handleSpeechDetected()
        } else if rmsDB < config.silenceThreshold {
            handleSilenceDetected()
        }
    }

    private func handleSpeechDetected() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        guard !isSpeechActive else { return }

        isSpeechActive = true
        speechStartTime = Date()

        isSpeechDetected = true
        onSpeechStart?()
    }

    private func handleSilenceDetected() {
        guard isSpeechActive else { return }

        if silenceTimer == nil {
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: config.silenceDuration,
                repeats: false
            ) { [weak self] _ in
                self?.handleSpeechEnded()
            }
        }
    }

    private func handleSpeechEnded() {
        guard isSpeechActive else { return }

        if let startTime = speechStartTime {
            let duration = Date().timeIntervalSince(startTime)

            if duration >= config.minSpeechDuration {
                isSpeechDetected = false
                onSpeechEnd?()
            }
        }

        isSpeechActive = false
        speechStartTime = nil

        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    deinit {
        stopMonitoring()
    }
}
