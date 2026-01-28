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
        var silenceDuration: TimeInterval = 1.5
        var minSpeechDuration: TimeInterval = 0.3
        var preSpeechBuffer: TimeInterval = 0.2
        var interruptThreshold: Float = -25.0  // ✅ NEW: Louder threshold for interrupt detection
    }
    
    // MARK: - Published State
    @Published var isSpeechDetected: Bool = false
    @Published var isListening: Bool = false
    @Published var currentAudioLevel: Float = -160.0
    @Published var isPaused: Bool = false  // ✅ NEW: Pause state
    
    // MARK: - Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onLoudSoundDetected: (() -> Void)?  // ✅ NEW: For interrupt detection during TTS
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private var config: VADConfig
    private var silenceTimer: Timer?
    private var speechStartTime: Date?
    private var isSpeechActive = false
    private var isInterruptMonitoringMode = false  // ✅ NEW: Special mode during TTS
    
    // MARK: - Initializer
    init(config: VADConfig = VADConfig()) {
        self.config = config
        super.init()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        guard !audioEngine.isRunning else { return }
        
        setupAudioSession()
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
        print("🛑 VAD monitoring stopped")
    }
    
    // ✅ NEW: Pause VAD processing (keeps audio engine running for interrupt detection)
    func pauseMonitoring() {
        guard isListening else { return }
        isPaused = true
        
        // Reset speech state
        isSpeechActive = false
        isSpeechDetected = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        speechStartTime = nil
        
        print("⏸️ VAD paused (still monitoring for interrupts)")
    }
    
    // ✅ NEW: Resume VAD processing
    func resumeMonitoring() {
        guard isListening else { return }
        isPaused = false
        isInterruptMonitoringMode = false
        print("▶️ VAD resumed")
    }
    
    // ✅ NEW: Enable interrupt monitoring mode (used during TTS)
    func enableInterruptMonitoring() {
        isInterruptMonitoringMode = true
        print("🎤 Interrupt monitoring enabled")
    }
    
    // ✅ NEW: Disable interrupt monitoring mode
    func disableInterruptMonitoring() {
        isInterruptMonitoringMode = false
    }
    
    func updateConfig(_ newConfig: VADConfig) {
        self.config = newConfig
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        // macOS doesn't need AVAudioSession configuration like iOS
    }
    
    private func setupAudioTap() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let avgPower = 20 * log10(rms)
        let audioLevel = max(-160.0, avgPower)
        
        DispatchQueue.main.async {
            self.currentAudioLevel = audioLevel
            self.onAudioLevel?(audioLevel)
            
            // ✅ Check for interrupt during TTS playback
            if self.isInterruptMonitoringMode {
                self.checkForInterrupt(audioLevel: audioLevel)
            }
            
            // ✅ Only process VAD if not paused
            if !self.isPaused {
                self.detectVoiceActivity(audioLevel: audioLevel)
            }
        }
    }
    
    // ✅ NEW: Check if user is trying to interrupt TTS
    private func checkForInterrupt(audioLevel: Float) {
        // Use a higher threshold to detect intentional speech over TTS
        if audioLevel > config.interruptThreshold {
            print("🎤 Interrupt detected! Audio level: \(audioLevel)")
            onLoudSoundDetected?()
        }
    }
    
    private func detectVoiceActivity(audioLevel: Float) {
        if audioLevel > config.speechThreshold {
            handleSpeechDetected()
        } else if audioLevel < config.silenceThreshold {
            handleSilenceDetected()
        }
    }
    
    private func handleSpeechDetected() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if !isSpeechActive {
            speechStartTime = Date()
            isSpeechActive = true
            
            DispatchQueue.main.async {
                self.isSpeechDetected = true
            }
            
            DispatchQueue.main.async {
                self.onSpeechStart?()
            }
        }
    }
    
    private func handleSilenceDetected() {
        guard isSpeechActive else { return }
        
        if silenceTimer == nil {
            silenceTimer = Timer.scheduledTimer(withTimeInterval: config.silenceDuration, repeats: false) { [weak self] _ in
                self?.handleSpeechEnded()
            }
        }
    }
    
    private func handleSpeechEnded() {
        guard isSpeechActive else { return }
        
        if let startTime = speechStartTime {
            let duration = Date().timeIntervalSince(startTime)
            
            if duration >= config.minSpeechDuration {
                DispatchQueue.main.async {
                    self.isSpeechDetected = false
                    self.onSpeechEnd?()
                }
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
