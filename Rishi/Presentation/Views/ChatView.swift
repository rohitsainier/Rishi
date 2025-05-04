//
//  ChatView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isTargeted: Bool = false
    @State private var activeChatId: UUID?
    
    var body: some View {
        VStack {
            if let _ = viewModel.currentChatId {
                ChatSessionView(viewModel: viewModel)
            } else {
                Text("No chat selected.")
                    .foregroundColor(.gray)
                    .font(.title)
            }
        }
        .onAppear {
            activeChatId = viewModel.currentChatId
        }
        .task {
            await viewModel.fetchAvailableModels()
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDroppedItems(providers)
        }
        .onChange(of: viewModel.isListening) { _, isActive in
            if isActive == false {
                let trimmed = viewModel.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    viewModel.currentInput = trimmed
                    viewModel.transcribedText = ""
                    viewModel.streamMessage(
                        model: viewModel.selectedModel,
                        systemPrompt: viewModel.selectedSystemPrompt.text,
                        attachedImages: viewModel.attachedImagesData
                    )
                }
            }
        }
        .onChange(of: viewModel.currentChatId) { _, newId in
            // Reset transient states
            activeChatId = newId
            viewModel.currentInput = ""
            viewModel.transcribedText = ""
            viewModel.attachedImages.removeAll()
            viewModel.cancelStreamingIfNeeded()
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
                    viewModel.attachedImages.append(image)
                }
            }
        }
        return true
    }
}
