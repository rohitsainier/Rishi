//
//  SpeechServiceProtocol.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

protocol SpeechServiceProtocol {
    // Expose read + publishers
    var isListeningPublisher: Published<Bool>.Publisher { get }
    var transcribedTextPublisher: Published<String>.Publisher { get }
    var errorMessagePublisher: Published<String?>.Publisher { get }
    
    var transcribedText: String { get }
    var isListening: Bool { get }
    var errorMessage: String? { get }
    
    func requestAuthorization()
    func toggleListening()
    func startListening()
    func stopListening()
}
