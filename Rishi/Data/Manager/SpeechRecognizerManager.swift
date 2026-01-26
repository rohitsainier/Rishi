//
//  SpeechRecognizerManager.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import AVFoundation
import Speech
import Combine

final class SpeechRecognizerManager: NSObject, SpeechServiceProtocol {
    // MARK: - VAD Mode
    enum RecognitionMode {
        case manual      // Push-to-talk (original behavior)
        case vad         // Automatic voice detection
    }
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var vadManager: VADManager?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String?
    @Published var currentMode: RecognitionMode = .vad  // Default to VAD mode
    @Published var audioLevel: Float = -160.0
    @Published var isSpeechDetected: Bool = false  // ✅ Now public
    
    public var isListeningPublisher: Published<Bool>.Publisher { $isListening }
    public var transcribedTextPublisher: Published<String>.Publisher { $transcribedText }
    public var errorMessagePublisher: Published<String?>.Publisher { $errorMessage }
    public var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }  // ✅ Expose this
    public var isSpeechDetectedPublisher: Published<Bool>.Publisher { $isSpeechDetected }  // ✅ Expose this

    override init() {
        super.init()
        requestAuthorization()
        setupVAD()
    }

    // MARK: - Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
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
    
    // MARK: - VAD Setup
    private func setupVAD() {
        vadManager = VADManager(config: VADManager.VADConfig(
            silenceThreshold: -40.0,
            speechThreshold: -35.0,
            silenceDuration: 1.5,
            minSpeechDuration: 0.3
        ))
        
        vadManager?.onSpeechStart = { [weak self] in
            DispatchQueue.main.async {
                self?.startListening()
            }
        }
        
        vadManager?.onSpeechEnd = { [weak self] in
            DispatchQueue.main.async {
                self?.stopListening()
            }
        }
        
        vadManager?.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
        
        // ✅ Bind VAD manager's published properties
        vadManager?.$isSpeechDetected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSpeechDetected, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Mode Control
    func setMode(_ mode: RecognitionMode) {
        currentMode = mode
        
        switch mode {
        case .manual:
            vadManager?.stopMonitoring()
        case .vad:
            if !isListening {
                vadManager?.startMonitoring()
            }
        }
    }
    
    // MARK: - VAD Control
    func startVADMonitoring() {
        guard currentMode == .vad else { return }
        vadManager?.startMonitoring()
    }
    
    func stopVADMonitoring() {
        vadManager?.stopMonitoring()
        if isListening {
            stopListening()
        }
    }

    // MARK: - Manual Control (original methods)
    func toggleListening() {
        if currentMode == .manual {
            isListening ? stopListening() : startListening()
        } else {
            // In VAD mode, toggle monitoring
            if vadManager?.isListening == true {
                stopVADMonitoring()
            } else {
                startVADMonitoring()
            }
        }
    }

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "❌ Speech recognizer not available"
            return
        }

        // Stop any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset transcription
        if !isListening {
            transcribedText = ""
        }
        
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
                // Only auto-stop in manual mode
                if self.currentMode == .manual {
                    self.stopListening()
                }
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
    
    deinit {
        stopListening()
        vadManager?.stopMonitoring()
    }
}
