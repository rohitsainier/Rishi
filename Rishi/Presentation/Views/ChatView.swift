//
//  ChatView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var battleViewModel: BattleViewModel
    @State private var isTargeted: Bool = false
    @State private var activeChatId: UUID?
    
    var body: some View {
        VStack {
            switch chatViewModel.activeScreen {
            case .chat:
                ChatSessionView(viewModel: chatViewModel)

            case .battle:
                BattleView(viewModel: battleViewModel)
            }
        }
        .onAppear {
            activeChatId = chatViewModel.currentChatId
        }
        .task {
            await chatViewModel.fetchAvailableModels()
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDroppedItems(providers)
        }
        .onChange(of: chatViewModel.isListening) { _, isActive in
            if isActive == false {
                let trimmed = chatViewModel.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chatViewModel.currentInput = trimmed
                    chatViewModel.transcribedText = ""
                    chatViewModel.streamMessage(
                        model: chatViewModel.selectedModel,
                        systemPrompt: chatViewModel.selectedSystemPrompt.text,
                        attachedImages: chatViewModel.attachedImagesData
                    )
                }
            }
        }
        .onChange(of: chatViewModel.currentChatId) { _, newId in
            // Reset transient states
            activeChatId = newId
            chatViewModel.currentInput = ""
            chatViewModel.transcribedText = ""
            chatViewModel.attachedImages.removeAll()
            chatViewModel.cancelStreamingIfNeeded()
        }
    }
    
    private func handleDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                guard let data = item as? Data,
                      let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?,
                      let image = NSImage(contentsOf: url) else {
                    print("❌ Failed to drop image")
                    return
                }
                
                DispatchQueue.main.async {
                    chatViewModel.attachedImages.append(image)
                }
            }
        }
        return true
    }
}
