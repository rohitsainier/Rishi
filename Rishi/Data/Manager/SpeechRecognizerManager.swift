//
//  SpeechRecognizerManager.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import AVFoundation
import Speech

final class SpeechRecognizerManager: NSObject, SpeechServiceProtocol {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String?
    
    public var isListeningPublisher: Published<Bool>.Publisher { $isListening }
    public var transcribedTextPublisher: Published<String>.Publisher { $transcribedText }
    public var errorMessagePublisher: Published<String?>.Publisher { $errorMessage }

    override init() {
        super.init()
        requestAuthorization()
    }

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Microphone authorized")
                case .denied:
                    self.errorMessage = "❌ Microphone access denied"
                case .restricted:
                    self.errorMessage = "❌ Speech recognition is restricted"
                case .notDetermined:
                    self.errorMessage = "❌ Permissions not determined"
                @unknown default:
                    self.errorMessage = "❌ Unknown speech auth error"
                }
            }
        }
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "❌ Speech recognizer not available"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""
        isListening = true

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "❌ Failed to create recognition request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "❌ Audio engine failed to start: \(error.localizedDescription)"
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }
}
