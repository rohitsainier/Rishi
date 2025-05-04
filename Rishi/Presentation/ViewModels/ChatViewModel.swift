//
//  ChatViewModel.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Chat State
    @Published var currentInput = ""
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var attachedImages: [NSImage] = []

    @Published var selectedModel: String = "gemma3:4b"
    @Published var availableModels: [String] = []
    
    // MARK: - System Prompt Options
    @Published var groupedSystemPrompts: [String: [SystemPrompt]] = [:]
    @Published var selectedSystemPrompt: SystemPrompt

    // MARK: - Speech State
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var voiceErrorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Services
    private let chatService: ChatServiceProtocol
    private let speechService: SpeechServiceProtocol

    // MARK: - Streaming
    private var streamingTask: Task<Void, Never>?
    private var currentStreamingMessageId: UUID?

    // MARK: - Computed: Image Data
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

    // MARK: - Init
    init(chatService: ChatServiceProtocol, speechService: SpeechServiceProtocol) {
        self.chatService = chatService
        self.speechService = speechService
        let allPrompts: [SystemPrompt] = [
            .init(text: "You are a helpful assistant.", category: "General"),
            .init(text: "Answer concisely and clearly.", category: "General"),
            
                .init(text: "Speak like Shakespeare.", category: "Creative"),
            .init(text: "Respond in poetic verse.", category: "Creative"),
            .init(text: "Pretend you are a pirate. Arr!", category: "Creative"),
            
                .init(text: "Respond as a motivational coach.", category: "Tone"),
            .init(text: "Respond like a sarcastic genius.", category: "Tone"),
            
                .init(text: "Provide step-by-step instructions.", category: "Instructional"),
            .init(text: "Act as a professional programmer.", category: "Instructional")
        ]
        
        // 🧠 Group them by category
        self.groupedSystemPrompts = Dictionary(grouping: allPrompts, by: { $0.category })
        
        // 🟢 Default to first General prompt
        self.selectedSystemPrompt = allPrompts.first!
        bindSpeechService()
    }

    // MARK: - Speech State Binding
    private func bindSpeechService() {
        speechService
            .isListeningPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$isListening)

        speechService
            .transcribedTextPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$transcribedText)

        speechService
            .errorMessagePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$voiceErrorMessage)
    }

    // MARK: - Microphone Control
    func toggleMic() {
        speechService.toggleListening()
    }

    func stopMic() {
        speechService.stopListening()
    }

    func startMic() {
        speechService.startListening()
    }

    // MARK: - Send Chat Message (Text and/or Image)
    func streamMessage(model: String, systemPrompt: String?, attachedImages: [Data] = []) {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty || !self.attachedImages.isEmpty else { return }

        // ✅ Store message with both text and image (displayed in UI)
        let userMessage = ChatMessage(
            sender: ChatMessageSender.user,
            content: trimmedInput,
            images: self.attachedImages.isEmpty ? nil : self.attachedImages
        )
        messages.append(userMessage)

        // ✅ Clear inputs
        currentInput = ""
        self.attachedImages.removeAll()
        isStreaming = true

        // Assistant placeholder
        let assistantMessage = ChatMessage(sender: ChatMessageSender.assistant, content: "")
        currentStreamingMessageId = assistantMessage.id
        messages.append(assistantMessage)

        // Cancel old stream
        streamingTask?.cancel()

        // Start new stream task
        streamingTask = Task {
            do {
                var streamedContent = ""
                let stream = try await chatService.sendStream(
                    messages: messages,
                    model: model,
                    systemPrompt: systemPrompt,
                    attachedImages: attachedImages
                )

                for try await token in stream {
                    streamedContent += token
                    updateAssistantMessage(content: streamedContent)
                }
            } catch {
                updateAssistantMessage(content: "⚠️ \(error.localizedDescription)")
            }

            isStreaming = false
        }
    }

    // MARK: - Stop Streaming
    func stopMessageStreaming() {
        chatService.stopStreaming()
        streamingTask?.cancel()
        isStreaming = false
    }

    // MARK: - Update Last Assistant Message
    private func updateAssistantMessage(content: String) {
        guard let id = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == id }) else { return }

        messages[index] = ChatMessage(
            id: id,
            sender: ChatMessageSender.assistant,
            content: content
        )
    }

    // MARK: - Fetch Models from Ollama
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
}
