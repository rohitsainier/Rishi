//
//  ChatServiceProtocol.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

protocol ChatServiceProtocol {
    func sendStream(
        messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        attachedImages: [Data]
    ) async throws -> AsyncThrowingStream<String, Error>
    
    func stopStreaming()
    func fetchAvailableModels() async throws -> [String]
}

