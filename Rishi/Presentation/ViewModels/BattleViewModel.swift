//
//  BattleViewModel.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//

import SwiftUI
import Combine

// Side Enum for clarity
enum BattleSide {
    case left, right
}

@MainActor
final class BattleViewModel: ObservableObject {
    
    // MARK: - Inputs from UI
    @Published var promptInput: String = ""
    @Published var isStreaming: Bool = false
    @Published var selectedLeftModel: String = "gemma3:4b"
    @Published var selectedRightModel: String = "gemma3:12b"
    @Published var availableModels: [String]

    // MARK: - Dependencies
    let chatService: ChatServiceProtocol

    // MARK: - Model-specific Messages
    @Published var leftMessages: [ChatMessage] = []
    @Published var rightMessages: [ChatMessage] = []

    // MARK: - Initializer
    init(chatService: ChatServiceProtocol, availableModels: [String] = []) {
        self.chatService = chatService
        self.availableModels = availableModels
    }

    // MARK: - Battle Logic

    func performBattle() async {
        let trimmedPrompt = promptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isStreaming = true

        let userMessage = ChatMessage(sender: .user, content: trimmedPrompt)

        // Reset messages independently
        leftMessages = [userMessage]
        rightMessages = [userMessage]

        let leftAssistant = ChatMessage(sender: .assistant, content: "", metadata: .init(model: selectedLeftModel))
        let rightAssistant = ChatMessage(sender: .assistant, content: "", metadata: .init(model: selectedRightModel))

        leftMessages.append(leftAssistant)
        rightMessages.append(rightAssistant)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.streamResponse(for: .left, model: self.selectedLeftModel, assistantMessageId: leftAssistant.id) }
            group.addTask { await self.streamResponse(for: .right, model: self.selectedRightModel, assistantMessageId: rightAssistant.id) }
        }

        isStreaming = false
    }

    // MARK: - Streaming Response

    private func streamResponse(for side: BattleSide, model: String, assistantMessageId: UUID) async {
        let messages = getMessages(for: side)

        do {
            var content = ""
            let stream = try await chatService.sendStream(messages: messages, model: model, systemPrompt: nil, attachedImages: [])

            for try await token in stream {
                content += token
                updateAssistantMessage(side: side, messageId: assistantMessageId, newContent: content, model: model)
            }

        } catch {
            print("❌ Streaming error for \(model): \(error.localizedDescription)")
            updateAssistantMessage(side: side, messageId: assistantMessageId, newContent: "⚠️ Error: \(error.localizedDescription)", model: model)
        }
    }

    // MARK: - Message Helpers

    private func getMessages(for side: BattleSide) -> [ChatMessage] {
        switch side {
            case .left: return leftMessages
            case .right: return rightMessages
        }
    }

    private func updateAssistantMessage(side: BattleSide, messageId: UUID, newContent: String, model: String) {
        switch side {
            case .left:
                if let index = leftMessages.firstIndex(where: { $0.id == messageId }) {
                    leftMessages[index] = ChatMessage(id: messageId, sender: .assistant, content: newContent, metadata: .init(model: model))
                }
            case .right:
                if let index = rightMessages.firstIndex(where: { $0.id == messageId }) {
                    rightMessages[index] = ChatMessage(id: messageId, sender: .assistant, content: newContent, metadata: .init(model: model))
                }
        }
    }

    // MARK: - Clear & Voting

    func vote(winnerModel: String) {
        print("✅ Voted for: \(winnerModel)")
        promptInput = ""
        clearChat()
    }

    func clearChat() {
        leftMessages.removeAll()
        rightMessages.removeAll()
        promptInput = ""
    }

    // MARK: - Load Models

    func fetchAvailableModels() async {
        do {
            availableModels = try await chatService.fetchAvailableModels()
        } catch {
            print("⚠️ Failed to fetch models: \(error)")
        }
    }
}
