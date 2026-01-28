//
//  SpeechServiceProtocol.swift
//  Rishi
//

import Foundation

protocol SpeechServiceProtocol {
    // Publishers
    var isListeningPublisher: Published<Bool>.Publisher { get }
    var transcribedTextPublisher: Published<String>.Publisher { get }
    var errorMessagePublisher: Published<String?>.Publisher { get }
    
    // State
    var transcribedText: String { get }
    var isListening: Bool { get }
    var errorMessage: String? { get }
    
    // Control
    func requestAuthorization()
    func toggleListening()
    func startListening()
    func stopListening()
}
