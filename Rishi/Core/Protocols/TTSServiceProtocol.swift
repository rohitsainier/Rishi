//
//  TTSServiceProtocol.swift
//  Rishi
//
//  Text-to-Speech Service Protocol
//


import Foundation

@MainActor
protocol TTSServiceProtocol {
    var isSpeakingPublisher: Published<Bool>.Publisher { get }
    var availableVoicesPublisher: Published<[String]>.Publisher { get }
    var selectedVoicePublisher: Published<String>.Publisher { get }
    var speechRatePublisher: Published<Float>.Publisher { get }
    
    var isSpeaking: Bool { get }
    var availableVoices: [String] { get }
    var selectedVoice: String { get set }
    var speechRate: Float { get set }
    
    func speak(_ text: String)
    func stopSpeaking()
    func pauseSpeaking()
    func continueSpeaking()
}
