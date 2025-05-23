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

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let sender: ChatMessageSender
    let content: String
    var imagesData: [Data]?  // Stores images as Data (Codable-compatible)
    var metadata: MessageMetadata?
    
    // NSImage is restored after decoding/encoding
    var images: [NSImage]? {
        imagesData?.compactMap { NSImage(data: $0) }
    }
    
    init(id: UUID = UUID(),
         sender: ChatMessageSender,
         content: String,
         images: [NSImage]? = nil, 
         metadata: MessageMetadata? = nil) {
        self.id = id
        self.sender = sender
        self.content = content
        self.imagesData = images?.compactMap { image in
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
            return bitmap.representation(using: .png, properties: [:])
        }
        self.metadata = metadata
    }
}

struct MessageMetadata: Codable, Equatable {
    var model: String?
    // Add other metadata like vote, etc.
}
