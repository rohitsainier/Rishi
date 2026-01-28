//
//  TTSManager.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//


import Foundation
import AVFoundation
import Combine

@MainActor
final class TTSManager: NSObject, TTSServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isSpeaking: Bool = false
    @Published var availableVoices: [String] = []
    @Published var selectedVoice: String = ""
    @Published var speechRate: Float = 0.5
    @Published var pitch: Float = 1.0          // ✅ NEW: 0.5 - 2.0
    @Published var volume: Float = 1.0         // ✅ NEW: 0.0 - 1.0
    
    public var isSpeakingPublisher: Published<Bool>.Publisher { $isSpeaking }
    public var availableVoicesPublisher: Published<[String]>.Publisher { $availableVoices }
    public var selectedVoicePublisher: Published<String>.Publisher { $selectedVoice }
    public var speechRatePublisher: Published<Float>.Publisher { $speechRate }
    public var pitchPublisher: Published<Float>.Publisher { $pitch }        // ✅ NEW
    public var volumePublisher: Published<Float>.Publisher { $volume }      // ✅ NEW
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private let audioQueue = DispatchQueue(label: "tts.audio.queue", qos: .userInitiated)
    private var voiceIdentifiers: [String: AVSpeechSynthesisVoice] = [:]
    
    // ✅ UserDefaults keys for persistence
    private enum SettingsKeys {
        static let selectedVoice = "tts_selected_voice"
        static let speechRate = "tts_speech_rate"
        static let pitch = "tts_pitch"
        static let volume = "tts_volume"
    }
    
    // MARK: - Configuration
    struct TTSConfig {
        var autoSpeak: Bool = true
        var defaultRate: Float = 0.5
        var defaultPitch: Float = 1.0
        var defaultVolume: Float = 1.0
        var preferredVoiceIdentifier: String?
    }
    
    private var config: TTSConfig
    
    // MARK: - Initializer
    init(config: TTSConfig = TTSConfig()) {
        self.config = config
        super.init()
        
        synthesizer.delegate = self
        loadAvailableVoices()
        loadSavedSettings()  // ✅ Load persisted settings
        
        // If no saved voice, select default
        if selectedVoice.isEmpty {
            selectDefaultVoice()
        }
    }
    
    // MARK: - Settings Persistence
    
    private func loadSavedSettings() {
        let defaults = UserDefaults.standard
        
        if let savedVoice = defaults.string(forKey: SettingsKeys.selectedVoice),
           availableVoices.contains(savedVoice) {
            selectedVoice = savedVoice
        }
        
        if defaults.object(forKey: SettingsKeys.speechRate) != nil {
            speechRate = defaults.float(forKey: SettingsKeys.speechRate)
        } else {
            speechRate = config.defaultRate
        }
        
        if defaults.object(forKey: SettingsKeys.pitch) != nil {
            pitch = defaults.float(forKey: SettingsKeys.pitch)
        } else {
            pitch = config.defaultPitch
        }
        
        if defaults.object(forKey: SettingsKeys.volume) != nil {
            volume = defaults.float(forKey: SettingsKeys.volume)
        } else {
            volume = config.defaultVolume
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(selectedVoice, forKey: SettingsKeys.selectedVoice)
        defaults.set(speechRate, forKey: SettingsKeys.speechRate)
        defaults.set(pitch, forKey: SettingsKeys.pitch)
        defaults.set(volume, forKey: SettingsKeys.volume)
        print("💾 TTS settings saved")
    }
    
    // MARK: - Voice Management
    private func loadAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        let englishVoices = voices
            .filter { $0.language.hasPrefix("en-") }
            .sorted { voice1, voice2 in
                if voice1.quality.rawValue != voice2.quality.rawValue {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
        
        voiceIdentifiers.removeAll()
        availableVoices.removeAll()
        
        for voice in englishVoices {
            let qualityBadge = voice.quality == .enhanced ? "⭐️ " : ""
            let displayName = "\(qualityBadge)\(voice.name) (\(voiceLanguageDescription(voice.language)))"
            voiceIdentifiers[displayName] = voice
            availableVoices.append(displayName)
        }
    }
    
    private func voiceLanguageDescription(_ languageCode: String) -> String {
        switch languageCode {
        case "en-US": return "US"
        case "en-GB": return "UK"
        case "en-AU": return "Australia"
        case "en-IE": return "Ireland"
        case "en-ZA": return "South Africa"
        case "en-IN": return "India"
        default: return languageCode
        }
    }
    
    private func selectDefaultVoice() {
        if let preferred = config.preferredVoiceIdentifier,
           availableVoices.contains(preferred) {
            selectedVoice = preferred
            return
        }
        
        // Prefer enhanced voices
        let premiumVoices = ["⭐️ Rishi (India)", "⭐️ Samantha (US)", "⭐️ Alex (US)", "⭐️ Daniel (UK)", "⭐️ Karen (Australia)"]
        for voice in premiumVoices {
            if availableVoices.contains(voice) {
                selectedVoice = voice
                return
            }
        }
        
        // Fallback to any Rishi or first available
        if let rishi = availableVoices.first(where: { $0.contains("Rishi") }) {
            selectedVoice = rishi
        } else {
            selectedVoice = availableVoices.first ?? ""
        }
    }
    
    // MARK: - Rate Conversion
    
    private func convertToUtteranceRate(_ userRate: Float) -> Float {
        let minRate: Float = 0.4
        let maxRate: Float = 0.6
        return minRate + (userRate * (maxRate - minRate))
    }
    
    // MARK: - Speech Control
    
    func speak(_ text: String) {
        let cleanedText = cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else { return }
        
        let utterance = createUtterance(for: cleanedText)
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
            
            self.synthesizer.speak(utterance)
        }
        
        isSpeaking = true
    }
    
    func previewVoice() {
            let text = "Hello! This is a preview of the selected voice."

            let utterance = createUtterance(for: text)

            audioQueue.async { [weak self] in
                guard let self = self else { return }

                if self.synthesizer.isSpeaking {
                    self.synthesizer.stopSpeaking(at: .immediate)
                }

                self.synthesizer.speak(utterance)
            }

            isSpeaking = true
        }
    
    private func createUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = voiceIdentifiers[selectedVoice] {
            utterance.voice = voice
        }
        
        utterance.rate = convertToUtteranceRate(speechRate)
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        return utterance
    }
    
    func stopSpeaking() {
            audioQueue.async { [weak self] in
                self?.synthesizer.stopSpeaking(at: .immediate)
            }

            isSpeaking = false
        }
    
    func pauseSpeaking() {
            audioQueue.async { [weak self] in
                self?.synthesizer.pauseSpeaking(at: .word)
            }
        }

        func continueSpeaking() {
            audioQueue.async { [weak self] in
                self?.synthesizer.continueSpeaking()
            }
        }
    
    // MARK: - Text Cleaning
    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
        
        cleaned = cleaned.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: "`[^`]+`",
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: "https?://[^\\s]+",
            with: "link",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: "#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSManager: AVSpeechSynthesizerDelegate {
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // isSpeaking remains true when paused
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
}
