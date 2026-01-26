//
//  VADManager.swift
//  Rishi
//
//  Created by Rohit Saini on 26/01/26.
//


import Foundation
import AVFoundation
import Combine

final class VADManager: NSObject {
    // MARK: - Configuration
    struct VADConfig {
        var silenceThreshold: Float = -40.0      // dB level to consider as silence
        var speechThreshold: Float = -35.0        // dB level to consider as speech
        var silenceDuration: TimeInterval = 1.5   // Seconds of silence before stopping
        var minSpeechDuration: TimeInterval = 0.3 // Minimum speech duration to trigger
        var preSpeechBuffer: TimeInterval = 0.2   // Capture audio before speech detected
    }
    
    // MARK: - Published State
    @Published var isSpeechDetected: Bool = false
    @Published var isListening: Bool = false
    @Published var currentAudioLevel: Float = -160.0
    
    // MARK: - Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private var config: VADConfig
    private var silenceTimer: Timer?
    private var speechStartTime: Date?
    private var isSpeechActive = false
    
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
        isSpeechDetected = false
        isSpeechActive = false
        speechStartTime = nil
        print("🛑 VAD monitoring stopped")
    }
    
    func updateConfig(_ newConfig: VADConfig) {
        self.config = newConfig
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        // macOS doesn't need AVAudioSession configuration like iOS
        // But we ensure permissions are handled elsewhere
    }
    
    private func setupAudioTap() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0) // Remove existing tap if any
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square) for audio level
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let avgPower = 20 * log10(rms) // Convert to dB
        let audioLevel = max(-160.0, avgPower) // Clamp minimum
        
        DispatchQueue.main.async {
            self.currentAudioLevel = audioLevel
            self.onAudioLevel?(audioLevel)
            self.detectVoiceActivity(audioLevel: audioLevel)
        }
    }
    
    private func detectVoiceActivity(audioLevel: Float) {
        // Speech detected
        if audioLevel > config.speechThreshold {
            handleSpeechDetected()
        }
        // Silence detected
        else if audioLevel < config.silenceThreshold {
            handleSilenceDetected()
        }
    }
    
    private func handleSpeechDetected() {
        // Cancel any pending silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if !isSpeechActive {
            // Mark speech as started
            speechStartTime = Date()
            isSpeechActive = true
            
            DispatchQueue.main.async {
                self.isSpeechDetected = true
            }
            
            // Notify speech start
            DispatchQueue.main.async {
                self.onSpeechStart?()
            }
        }
    }
    
    private func handleSilenceDetected() {
        guard isSpeechActive else { return }
        
        // Start silence timer if not already running
        if silenceTimer == nil {
            silenceTimer = Timer.scheduledTimer(withTimeInterval: config.silenceDuration, repeats: false) { [weak self] _ in
                self?.handleSpeechEnded()
            }
        }
    }
    
    private func handleSpeechEnded() {
        guard isSpeechActive else { return }
        
        // Check if speech was long enough
        if let startTime = speechStartTime {
            let duration = Date().timeIntervalSince(startTime)
            
            if duration >= config.minSpeechDuration {
                // Valid speech detected
                DispatchQueue.main.async {
                    self.isSpeechDetected = false
                    self.onSpeechEnd?()
                }
            }
        }
        
        // Reset state
        isSpeechActive = false
        speechStartTime = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
