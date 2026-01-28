//
//  ChatViewModel.swift
//  Rishi
//

import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var activeScreen: ScreenType = .chat
    @Published var currentInput = ""
    @Published var isStreaming = false
    @Published var attachedImages: [NSImage] = []

    @Published var selectedModel: String = "translategemma"
    @Published var availableModels: [String] = []

    @Published var chatHistories: [ChatHistory] = []
    @Published var currentChatId: UUID?
    
    // VAD
    @Published var vadEnabled: Bool = true
    @Published var audioLevel: Float = -160.0
    @Published var isSpeechDetected: Bool = false
    @Published var isVADPaused: Bool = false  // ✅ NEW: Track VAD pause state
    
    // TTS
    @Published var ttsEnabled: Bool = true  // ✅ Changed default to true for testing
    @Published var isSpeaking: Bool = false
    @Published var availableVoices: [String] = []
    @Published var selectedVoice: String = ""
    @Published var speechRate: Float = 0.5

    // MARK: - Computed Properties
    var currentChatTitle: String {
        currentChat?.name ?? "Chat"
    }

    var messages: [ChatMessage] {
        get {
            guard let id = currentChatId else { return [] }
            return historyService.chatMessages(for: id)
        }
        set {
            guard let id = currentChatId else { return }
            historyService.updateChatMessages(for: id, messages: newValue)
            chatHistories = historyService.histories
        }
    }

    private var currentChat: ChatHistory? {
        guard let id = currentChatId else { return nil }
        return historyService.histories.first(where: { $0.id == id })
    }

    var attachedImagesData: [Data] {
        attachedImages.compactMap {
            guard let tiff = $0.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
            return bitmap.representation(using: .png, properties: [:])
        }
    }

    var groupedPromptCategories: [String] {
        groupedSystemPrompts.keys.sorted()
    }

    let groupedSystemPrompts: [String: [SystemPrompt]]
    @Published var selectedSystemPrompt: SystemPrompt

    // MARK: - Speech State
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var voiceErrorMessage: String? = nil

    // MARK: - Services
    let chatService: ChatServiceProtocol
    private let speechService: SpeechServiceProtocol
    private let historyService: ChatHistoryServiceProtocol
    private var ttsService: TTSServiceProtocol

    // MARK: - Private State
    private var streamingTask: Task<Void, Never>?
    private var currentStreamingMessageId: UUID?
    private var cancellables = Set<AnyCancellable>()
    private var resumeVADWorkItem: DispatchWorkItem?  // ✅ NEW: For delayed VAD resume

    // MARK: - Init
    init(
        chatService: ChatServiceProtocol,
        speechService: SpeechServiceProtocol,
        historyService: ChatHistoryServiceProtocol,
        ttsService: TTSServiceProtocol
    ) {
        self.chatService = chatService
        self.speechService = speechService
        self.historyService = historyService
        self.ttsService = ttsService

        let prompts: [SystemPrompt] = [
            .init(text: "You are a helpful assistant.", category: "General"),
            .init(text: "Answer concisely and clearly.", category: "General"),
            .init(text: "Speak like Shakespeare.", category: "Creative"),
            .init(text: "Respond in poetic verse.", category: "Creative"),
            .init(text: "Pretend you are a pirate. Arr!", category: "Creative"),
            .init(text: "Respond as a motivational coach.", category: "Tone"),
            .init(text: "Respond like a sarcastic genius.", category: "Tone"),
            .init(text: "Provide step-by-step instructions.", category: "Instructional"),
            .init(text: "Act as a professional programmer.", category: "Instructional"),
            .init(text: "I would like you to act as an SVG designer. I will ask you to create images, and you will come up with SVG code for the image, nothing else no explanation nothing just code. My first request is: give me an image of a red circle.", category: "SVG")
        ]

        self.groupedSystemPrompts = Dictionary(grouping: prompts, by: { $0.category })
        self.selectedSystemPrompt = prompts.first!

        historyService.load()
        chatHistories = historyService.histories
        currentChatId = historyService.currentChatId ?? historyService.histories.first?.id ?? createNewChat().id

        bindSpeechService()
        bindTTSService()
        setupInterruptHandler()  // ✅ NEW
    }

    // MARK: - History Management
    func createNewChat() -> ChatHistory {
        currentInput = ""
        attachedImages.removeAll()
        transcribedText = ""
        isStreaming = false
        streamingTask?.cancel()

        let new = historyService.createNewChat()
        chatHistories = historyService.histories
        currentChatId = new.id
        return new
    }

    func deleteChat(id: UUID) {
        historyService.deleteChat(withId: id)
        chatHistories = historyService.histories
        currentChatId = historyService.currentChatId
    }

    func selectChat(id: UUID) {
        currentChatId = id
    }

    // MARK: - Streaming
    func streamMessage(model: String, systemPrompt: String?, attachedImages: [Data] = []) {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty || !self.attachedImages.isEmpty else { return }

        // ✅ Stop any ongoing speech immediately
        if ttsEnabled && isSpeaking {
            ttsService.stopSpeaking()
        }

        let userMessage = ChatMessage(
            sender: .user,
            content: trimmedInput,
            images: self.attachedImages.isEmpty ? nil : self.attachedImages
        )
        messages.append(userMessage)

        currentInput = ""
        self.attachedImages.removeAll()
        isStreaming = true

        let assistantMessage = ChatMessage(sender: .assistant, content: "")
        currentStreamingMessageId = assistantMessage.id
        messages.append(assistantMessage)

        streamingTask?.cancel()

        streamingTask = Task {
            do {
                var streamed = ""

                let stream = try await chatService.sendStream(
                    messages: messages,
                    model: model,
                    systemPrompt: systemPrompt,
                    attachedImages: attachedImages
                )

                for try await token in stream {
                    streamed += token
                    updateAssistantMessage(content: streamed)
                }
                
                // ✅ Speak the final response
                if ttsEnabled && !streamed.isEmpty {
                    ttsService.speak(streamed)
                }
                
            } catch {
                updateAssistantMessage(content: "⚠️ \(error.localizedDescription)")
            }

            isStreaming = false
        }
    }

    func stopMessageStreaming() {
        chatService.stopStreaming()
        streamingTask?.cancel()
        isStreaming = false
    }

    func cancelStreamingIfNeeded() {
        streamingTask?.cancel()
        isStreaming = false
    }

    private func updateAssistantMessage(content: String) {
        guard let id = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == id }) else { return }

        messages[index] = ChatMessage(
            id: id,
            sender: .assistant,
            content: content
        )
        chatHistories = historyService.histories
    }

    // MARK: - Speech Service Binding
    private func bindSpeechService() {
        speechService.isListeningPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$isListening)

        speechService.transcribedTextPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$transcribedText)

        speechService.errorMessagePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$voiceErrorMessage)
        
        if let speechManager = speechService as? SpeechRecognizerManager {
            speechManager.audioLevelPublisher
                .receive(on: RunLoop.main)
                .assign(to: &$audioLevel)
            
            speechManager.isSpeechDetectedPublisher
                .receive(on: RunLoop.main)
                .assign(to: &$isSpeechDetected)
            
            // ✅ NEW: Bind VAD pause state
            speechManager.isVADPausedPublisher
                .receive(on: RunLoop.main)
                .assign(to: &$isVADPaused)
        }
    }
    
    // MARK: - TTS Service Binding
    private func bindTTSService() {
        // ✅ UPDATED: Use sink to handle TTS state changes
        ttsService.isSpeakingPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] speaking in
                guard let self = self else { return }
                self.isSpeaking = speaking
                
                if speaking {
                    self.handleTTSStarted()
                } else {
                    self.handleTTSStopped()
                }
            }
            .store(in: &cancellables)
        
        ttsService.availableVoicesPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$availableVoices)
        
        ttsService.selectedVoicePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$selectedVoice)
        
        ttsService.speechRatePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$speechRate)
    }
    
    // ✅ NEW: Setup interrupt handler
    private func setupInterruptHandler() {
        if let speechManager = speechService as? SpeechRecognizerManager {
            speechManager.onInterruptDetected = { [weak self] in
                guard let self = self else { return }
                
                // Only handle interrupt if TTS is actually speaking
                if self.isSpeaking {
                    print("🛑 User interrupted TTS - stopping speech")
                    self.stopSpeaking()
                }
            }
        }
    }
    
    // ✅ NEW: Handle TTS started - pause VAD to prevent feedback
    private func handleTTSStarted() {
        guard vadEnabled else { return }
        
        print("🔊 TTS started - pausing VAD")
        
        // Cancel any pending resume
        resumeVADWorkItem?.cancel()
        resumeVADWorkItem = nil
        
        // Pause VAD to prevent capturing TTS audio
        if let manager = speechService as? SpeechRecognizerManager {
            manager.pauseVAD()
            // Enable interrupt monitoring so user can still interrupt
            manager.enableInterruptMonitoring()
        }
    }
    
    // ✅ NEW: Handle TTS stopped - resume VAD after delay
    private func handleTTSStopped() {
        guard vadEnabled else { return }
        
        print("🔇 TTS stopped - scheduling VAD resume")
        
        // Cancel any pending resume
        resumeVADWorkItem?.cancel()
        
        // Resume VAD after a short delay (to avoid capturing TTS tail audio)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Double-check TTS is still not speaking
            guard !self.isSpeaking else {
                print("⚠️ TTS started again - not resuming VAD")
                return
            }
            
            print("▶️ Resuming VAD after TTS")
            if let manager = self.speechService as? SpeechRecognizerManager {
                manager.disableInterruptMonitoring()
                manager.resumeVAD()
            }
        }
        
        resumeVADWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func updateChatTitle(chatId: UUID, newTitle: String) {
        historyService.updateChatTitle(for: chatId, newTitle: newTitle)
        chatHistories = historyService.histories
    }

    // MARK: - Mic Control
    func toggleMic() { speechService.toggleListening() }
    func stopMic() { speechService.stopListening() }
    func startMic() { speechService.startListening() }
    
    // MARK: - VAD Control
    func toggleVADMode() {
        vadEnabled.toggle()
        if let manager = speechService as? SpeechRecognizerManager {
            manager.setMode(vadEnabled ? .vad : .manual)
        }
    }

    func startVAD() {
        guard vadEnabled else { return }
        // Don't start if TTS is speaking
        guard !isSpeaking else {
            print("⚠️ Not starting VAD - TTS is speaking")
            return
        }
        if let manager = speechService as? SpeechRecognizerManager {
            manager.startVADMonitoring()
        }
    }

    func stopVAD() {
        if let manager = speechService as? SpeechRecognizerManager {
            manager.stopVADMonitoring()
        }
    }
    
    // MARK: - TTS Control
    func toggleTTS() {
        ttsEnabled.toggle()
        if !ttsEnabled {
            ttsService.stopSpeaking()
        }
    }

    func stopSpeaking() {
        ttsService.stopSpeaking()
        // Resume VAD immediately when manually stopped
        handleTTSStopped()
    }

    func pauseSpeaking() {
        ttsService.pauseSpeaking()
    }

    func continueSpeaking() {
        ttsService.continueSpeaking()
    }

    func setVoice(_ voice: String) {
        ttsService.selectedVoice = voice
    }

    func setSpeechRate(_ rate: Float) {
        ttsService.speechRate = rate
    }

    // MARK: - Model Fetching
    func fetchAvailableModels() async {
        do {
            let models = try await chatService.fetchAvailableModels()
            self.availableModels = models
            if self.selectedModel.isEmpty, let first = models.first {
                self.selectedModel = first
            }
        } catch {
            print("Model fetch failed: \(error)")
        }
    }
    
    func generateTitleForChat(id chatId: UUID) async {
        guard let chat = chatHistories.first(where: { $0.id == chatId }),
              chat.name.hasPrefix("New Chat") || chat.name.hasPrefix("Chat on"),
              !chat.messages.isEmpty else {
            return
        }

        let recentMessages = Array(chat.messages.prefix(3))
        var summaryMessages: [ChatMessage] = recentMessages
        summaryMessages.append(
            ChatMessage(sender: .user, content: "Summarize this conversation in 3-5 words.")
        )

        do {
            let stream = try await chatService.sendStream(
                messages: summaryMessages,
                model: selectedModel,
                systemPrompt: "You are summarizing a conversation. Respond with only a short title, nothing else.",
                attachedImages: []
            )

            var result = ""
            for try await token in stream {
                result += token
            }

            let newTitle = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTitle.isEmpty {
                updateChatTitle(chatId: chatId, newTitle: newTitle)
            }
        } catch {
            print("❌ Title generation failed: \(error.localizedDescription)")
        }
    }
}
