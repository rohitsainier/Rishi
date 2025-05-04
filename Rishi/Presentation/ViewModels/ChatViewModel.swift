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
    // MARK: - Active Chat Session
    @Published var currentInput = ""
    @Published var isStreaming = false
    @Published var attachedImages: [NSImage] = []

    @Published var selectedModel: String = "gemma3:4b"
    @Published var availableModels: [String] = []

    @Published var chatHistories: [ChatHistory] = []
    @Published var currentChatId: UUID?

    // Computed: current chat messages
    var messages: [ChatMessage] {
        get {
            guard let index = currentChatIndex else { return [] }
            return chatHistories[index].messages
        }
        set {
            guard let index = currentChatIndex else { return }
            chatHistories[index].messages = newValue
            persistHistories()
        }
    }
    
    var currentChatTitle: String {
        chatHistories.first(where: { $0.id == currentChatId })?.name ?? "Chat"
    }

    private var currentChatIndex: Int? {
        chatHistories.firstIndex(where: { $0.id == currentChatId })
    }
    

    // MARK: - System Prompt Options
    @Published var groupedSystemPrompts: [String: [SystemPrompt]] = [:]
    @Published var selectedSystemPrompt: SystemPrompt

    // MARK: - Speech State
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var voiceErrorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    private let chatService: ChatServiceProtocol
    private let speechService: SpeechServiceProtocol

    // Streaming
    private var streamingTask: Task<Void, Never>?
    private var currentStreamingMessageId: UUID?

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

        self.groupedSystemPrompts = Dictionary(grouping: allPrompts, by: { $0.category })
        self.selectedSystemPrompt = allPrompts.first!

        loadHistories()
        if chatHistories.isEmpty {
            createNewChat()
        }

        bindSpeechService()
    }
    
    func cancelStreamingIfNeeded() {
        streamingTask?.cancel()
        isStreaming = false
    }

    // MARK: - Chat History Management
    func createNewChat() {
        currentInput = ""
        attachedImages.removeAll()
        transcribedText = ""
        isStreaming = false
        streamingTask?.cancel()

        let new = ChatHistory(
            id: UUID(),
            name: "New Chat \(chatHistories.count + 1)",
            messages: [],
            createdAt: Date()
        )
        chatHistories.insert(new, at: 0)
        currentChatId = new.id
        persistHistories()
    }

    func deleteChat(id: UUID) {
        chatHistories.removeAll { $0.id == id }
        if currentChatId == id {
            currentChatId = chatHistories.first?.id
        }
        persistHistories()
    }

    func selectChat(id: UUID) {
        self.currentChatId = id
    }

    // Save & Load Chats
    private func persistHistories() {
        do {
            let jsonData = try JSONEncoder().encode(chatHistories)
            let url = chatStorageURL()
            try jsonData.write(to: url)
        } catch {
            print("Failed to persist chat histories: \(error)")
        }
    }

    private func loadHistories() {
        let url = chatStorageURL()
        do {
            let data = try Data(contentsOf: url)
            let histories = try JSONDecoder().decode([ChatHistory].self, from: data)
            self.chatHistories = histories
            self.currentChatId = histories.first?.id
        } catch {
            print("⚠️ Failed to load saved chats: \(error)")
        }
    }

    private func chatStorageURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ChatHistories.json")
    }

    // MARK: - Message Streaming Logic
    func streamMessage(model: String, systemPrompt: String?, attachedImages: [Data] = []) {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty || !self.attachedImages.isEmpty else { return }

        let userMessage = ChatMessage(
            sender: .user,
            content: trimmedInput,
            images: self.attachedImages.isEmpty ? nil : self.attachedImages)

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
            } catch {
                updateAssistantMessage(content: "⚠️ \(error.localizedDescription)")
            }

            isStreaming = false
        }
    }

    private func updateAssistantMessage(content: String) {
        guard let id = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == id }) else { return }

        messages[index] = ChatMessage(
            id: id,
            sender: .assistant,
            content: content
        )
        persistHistories()
    }

    func stopMessageStreaming() {
        chatService.stopStreaming()
        streamingTask?.cancel()
        isStreaming = false
    }

    // MARK: - Voice Transcription
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
    }

    func toggleMic() { speechService.toggleListening() }
    func stopMic() { speechService.stopListening() }
    func startMic() { speechService.startListening() }

    // MARK: - Fetch Model
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
