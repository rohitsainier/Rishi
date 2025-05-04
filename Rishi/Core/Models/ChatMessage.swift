//
//  ChatMessage.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation
import AppKit

enum ChatMessageSender: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id: UUID
    let sender: ChatMessageSender
    let content: String
    let images: [NSImage]?

    init(id: UUID = UUID(),
         sender: ChatMessageSender,
         content: String,
         images: [NSImage]? = nil) {
        self.id = id
        self.sender = sender
        self.content = content
        self.images = images
    }
}
