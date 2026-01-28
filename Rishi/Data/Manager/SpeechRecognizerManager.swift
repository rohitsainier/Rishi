//
//  SpeechRecognizerManager.swift
//  Rishi
//

import SwiftUI
import AVFoundation
import Speech
import Combine

final class SpeechRecognizerManager: NSObject, SpeechServiceProtocol {
    // MARK: - VAD Mode
    enum RecognitionMode {
        case manual
        case vad
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
    @Published var currentMode: RecognitionMode = .vad
    @Published var audioLevel: Float = -160.0
    @Published var isSpeechDetected: Bool = false
    @Published var isVADPaused: Bool = false  // ✅ NEW: Track VAD pause state
    
    public var isListeningPublisher: Published<Bool>.Publisher { $isListening }
    public var transcribedTextPublisher: Published<String>.Publisher { $transcribedText }
    public var errorMessagePublisher: Published<String?>.Publisher { $errorMessage }
    public var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    public var isSpeechDetectedPublisher: Published<Bool>.Publisher { $isSpeechDetected }
    public var isVADPausedPublisher: Published<Bool>.Publisher { $isVADPaused }  // ✅ NEW

    // ✅ NEW: Callback for interrupt detection
    var onInterruptDetected: (() -> Void)?

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
            minSpeechDuration: 0.3,
            interruptThreshold: -25.0  // ✅ NEW: Louder threshold for interrupts
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
        
        // ✅ NEW: Handle interrupt detection
        vadManager?.onLoudSoundDetected = { [weak self] in
            DispatchQueue.main.async {
                self?.onInterruptDetected?()
            }
        }
        
        vadManager?.$isSpeechDetected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSpeechDetected, on: self)
            .store(in: &cancellables)
        
        // ✅ NEW: Bind pause state
        vadManager?.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: \.isVADPaused, on: self)
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
    
    // ✅ NEW: Pause VAD (used during TTS)
    func pauseVAD() {
        vadManager?.pauseMonitoring()
    }
    
    // ✅ NEW: Resume VAD (used after TTS)
    func resumeVAD() {
        vadManager?.resumeMonitoring()
    }
    
    // ✅ NEW: Enable interrupt monitoring during TTS
    func enableInterruptMonitoring() {
        vadManager?.enableInterruptMonitoring()
    }
    
    // ✅ NEW: Disable interrupt monitoring
    func disableInterruptMonitoring() {
        vadManager?.disableInterruptMonitoring()
    }

    // MARK: - Manual Control
    func toggleListening() {
        if currentMode == .manual {
            isListening ? stopListening() : startListening()
        } else {
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

        recognitionTask?.cancel()
        recognitionTask = nil
        
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
