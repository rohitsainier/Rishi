//
//  ChatHistoryService.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

final class ChatHistoryService: ChatHistoryServiceProtocol {
    private(set) var histories: [ChatHistory] = []
    var currentChatId: UUID?

    func load() {
        let url = chatStorageURL()
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([ChatHistory].self, from: data)
            self.histories = loaded
            self.currentChatId = loaded.first?.id
        } catch {
            print("⚠️ Failed to load saved chats: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(histories)
            try data.write(to: chatStorageURL())
        } catch {
            print("❌ Failed to save chat histories: \(error)")
        }
    }

    func createNewChat() -> ChatHistory {
        let new = ChatHistory(
            id: UUID(),
            name: "New Chat \(histories.count + 1)",
            messages: [],
            createdAt: Date()
        )
        histories.insert(new, at: 0)
        currentChatId = new.id
        save()
        return new
    }

    func deleteChat(withId id: UUID) {
        histories.removeAll { $0.id == id }
        if currentChatId == id {
            currentChatId = histories.first?.id
        }
        save()
    }

    func updateChatMessages(for id: UUID, messages: [ChatMessage]) {
        guard let index = histories.firstIndex(where: { $0.id == id }) else { return }
        histories[index].messages = messages
        save()
    }

    func chatMessages(for id: UUID) -> [ChatMessage] {
        histories.first(where: { $0.id == id })?.messages ?? []
    }
    
    func updateChatTitle(for id: UUID, newTitle: String) {
        guard let index = histories.firstIndex(where: { $0.id == id }) else { return }
        histories[index].name = newTitle
        save()
    }

    private func chatStorageURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ChatHistories.json")
    }
}
