//
//  TTSServiceProtocol.swift
//  Rishi
//
//  Text-to-Speech Service Protocol
//


import Foundation

@MainActor
protocol TTSServiceProtocol {
    // Publishers
    var isSpeakingPublisher: Published<Bool>.Publisher { get }
    var availableVoicesPublisher: Published<[String]>.Publisher { get }
    var selectedVoicePublisher: Published<String>.Publisher { get }
    var speechRatePublisher: Published<Float>.Publisher { get }
    var pitchPublisher: Published<Float>.Publisher { get }      // ✅ NEW
    var volumePublisher: Published<Float>.Publisher { get }     // ✅ NEW
    
    // State
    var isSpeaking: Bool { get }
    var availableVoices: [String] { get }
    var selectedVoice: String { get set }
    var speechRate: Float { get set }
    var pitch: Float { get set }           // ✅ NEW
    var volume: Float { get set }          // ✅ NEW
    
    // Control
    func speak(_ text: String)
    func stopSpeaking()
    func pauseSpeaking()
    func continueSpeaking()
    func previewVoice()                    // ✅ NEW
}
