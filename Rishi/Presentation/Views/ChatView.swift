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
    @State private var isImporting = false
    @State private var isTargeted: Bool = false
    @State private var showPromptPicker = false
    @State private var showModelPicker = false
    
    var body: some View {
        VStack {
            // Header: Model and Prompt
            // Header: Model and Prompt
            ChatHeaderBar(showModelPicker: $showModelPicker,
                          showChatTypePicker: $showPromptPicker,
                          selectedModel: viewModel.selectedModel,
                          selectedChatType: viewModel.selectedSystemPrompt.text)

            // ✅ Sheet for System Prompt
            .sheet(isPresented: $showPromptPicker) {
                SystemPromptSheetView(viewModel: viewModel, isPresented: $showPromptPicker)
            }

            // ✅ Sheet for Model Picker
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheetView(viewModel: viewModel, isPresented: $showModelPicker)
            }
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .onChange(of: viewModel.messages.last?.content.count) {
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Attached Image Previews
            if !viewModel.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(viewModel.attachedImages.enumerated()), id: \.offset) { index, image in
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3))
                                )
                                .contextMenu {
                                    Button("Remove") {
                                        viewModel.attachedImages.remove(at: index)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
            }
            
            MessageInputView(
                input: viewModel.isListening ? $viewModel.transcribedText : $viewModel.currentInput,
                isStreaming: $viewModel.isStreaming,
                attachedImages: $viewModel.attachedImages,
                isListening: viewModel.isListening,
                voiceErrorMessage: viewModel.voiceErrorMessage,
                onSend: {
                    viewModel.streamMessage(
                        model: viewModel.selectedModel,
                        systemPrompt: viewModel.selectedSystemPrompt.text,
                        attachedImages: viewModel.attachedImagesData
                    )
                },
                onStop: {
                    viewModel.stopMessageStreaming()
                },
                onToggleMic: {
                    viewModel.toggleMic()
                },
                onImportImages: { images in
                    viewModel.attachedImages.append(contentsOf: images)
                }
            )
            .padding()
            .background(
                KeyboardMonitor {
                    viewModel.toggleMic()
                }
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDroppedItems(providers)
        }
        .navigationTitle("What can I help with?")
        .task {
            await viewModel.fetchAvailableModels()
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
