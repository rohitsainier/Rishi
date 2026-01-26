//
//  TTSManager.swift
//  Rishi
//
//  Text-to-Speech Manager using AVSpeechSynthesizer
//

import Foundation
import AVFoundation
import Combine

final class TTSManager: NSObject, TTSServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isSpeaking: Bool = false
    @Published var availableVoices: [String] = []
    @Published var selectedVoice: String = ""
    @Published var speechRate: Float = 0.5 // 0.0 (slow) to 1.0 (fast)
    
    public var isSpeakingPublisher: Published<Bool>.Publisher { $isSpeaking }
    public var availableVoicesPublisher: Published<[String]>.Publisher { $availableVoices }
    public var selectedVoicePublisher: Published<String>.Publisher { $selectedVoice }
    public var speechRatePublisher: Published<Float>.Publisher { $speechRate }
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var voiceIdentifiers: [String: AVSpeechSynthesisVoice] = [:]
    
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
        self.speechRate = config.defaultRate
        super.init()
        
        synthesizer.delegate = self
        loadAvailableVoices()
        selectDefaultVoice()
    }
    
    // MARK: - Voice Management
    private func loadAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter for English voices and sort by quality
        let englishVoices = voices
            .filter { $0.language.hasPrefix("en-") }
            .sorted { voice1, voice2 in
                // Prioritize enhanced/premium voices
                if voice1.quality.rawValue != voice2.quality.rawValue {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
        
        for voice in englishVoices {
            let displayName = "\(voice.name) (\(voiceLanguageDescription(voice.language)))"
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
        // Try to use preferred voice from config
        if let preferred = config.preferredVoiceIdentifier,
           availableVoices.contains(preferred) {
            selectedVoice = preferred
            return
        }
        
        // Look for premium/enhanced voices
        let premiumVoices = ["Samantha (US)", "Alex (US)", "Daniel (UK)", "Karen (Australia)"]
        for voice in premiumVoices {
            if availableVoices.contains(voice) {
                selectedVoice = voice
                return
            }
        }
        
        // Fallback to first available
        selectedVoice = availableVoices.first ?? ""
    }
    
    // MARK: - Speech Control
    func speak(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Clean the text (remove markdown, code blocks, etc.)
        let cleanedText = cleanTextForSpeech(text)
        
        guard !cleanedText.isEmpty else {
            print("⚠️ No text to speak after cleaning")
            return
        }
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        
        // Apply voice if selected
        if let voice = voiceIdentifiers[selectedVoice] {
            utterance.voice = voice
        }
        
        // Apply speech parameters
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        utterance.pitchMultiplier = config.defaultPitch
        utterance.volume = config.defaultVolume
        
        // Speak
        synthesizer.speak(utterance)
        isSpeaking = true
        
        print("🔊 Speaking: \(cleanedText.prefix(50))...")
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - Text Cleaning
    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove markdown code blocks
        cleaned = cleaned.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        
        // Remove inline code
        cleaned = cleaned.replacingOccurrences(
            of: "`[^`]+`",
            with: "",
            options: .regularExpression
        )
        
        // Remove SVG/HTML tags
        cleaned = cleaned.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Remove URLs
        cleaned = cleaned.replacingOccurrences(
            of: "https?://[^\\s]+",
            with: "link",
            options: .regularExpression
        )
        
        // Remove markdown headers
        cleaned = cleaned.replacingOccurrences(
            of: "#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )
        
        // Remove markdown bold/italic
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        
        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // Trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // isSpeaking remains true when paused
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
}
