//
//  ChatHistoryServiceProtocol.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

protocol ChatHistoryServiceProtocol {
    var histories: [ChatHistory] { get }
    var currentChatId: UUID? { get set }

    func load()
    func save()

    func createNewChat() -> ChatHistory
    func deleteChat(withId id: UUID)
    func updateChatMessages(for id: UUID, messages: [ChatMessage])
    func chatMessages(for id: UUID) -> [ChatMessage]
}
