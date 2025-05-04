//
//  Dependencies.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

final class AppDI {
    @MainActor
    static func makeChatViewModel() -> ChatViewModel {
        return ChatViewModel(chatService: OllamaService(),
                             speechService: SpeechRecognizerManager())
    }
}
