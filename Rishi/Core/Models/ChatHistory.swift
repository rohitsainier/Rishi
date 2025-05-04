//
//  ChatHistory.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

struct ChatHistory: Identifiable, Codable {
    let id: UUID
    var name: String 
    var messages: [ChatMessage]
    var createdAt: Date
}
