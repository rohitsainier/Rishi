//
//  ChatSessionView.swift
//  Rishi
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatSessionView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showPromptPicker = false
    @State private var showModelPicker = false
    @State private var showTTSSettings = false  // ✅ NEW
    
    var body: some View {
        VStack {
            // Header
            ChatHeaderBar(
                showModelPicker: $showModelPicker,
                showChatTypePicker: $showPromptPicker,
                selectedModel: viewModel.selectedModel,
                selectedChatType: viewModel.selectedSystemPrompt.text
            )
            .sheet(isPresented: $showPromptPicker) {
                SystemPromptSheetView(viewModel: viewModel, isPresented: $showPromptPicker)
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheetView(viewModel: viewModel, isPresented: $showModelPicker)
            }
            // ✅ NEW: TTS Settings Sheet
            .sheet(isPresented: $showTTSSettings) {
                TTSSettingsView(viewModel: viewModel, isPresented: $showTTSSettings)
            }
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if viewModel.messages.isEmpty {
                        Text("Start typing to begin your conversation.")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .onChange(of: viewModel.messages.last?.content.count) {
                    DispatchQueue.main.async {
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Attached Images
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
                }.padding(.horizontal)
            }
            
            // Input Area
            MessageInputView(
                input: viewModel.isListening ? $viewModel.transcribedText : $viewModel.currentInput,
                isStreaming: $viewModel.isStreaming,
                attachedImages: $viewModel.attachedImages,
                isListening: viewModel.isListening,
                voiceErrorMessage: viewModel.voiceErrorMessage,
                vadEnabled: viewModel.vadEnabled,
                audioLevel: viewModel.audioLevel,
                isSpeechDetected: viewModel.isSpeechDetected,
                ttsEnabled: viewModel.ttsEnabled,
                isSpeaking: viewModel.isSpeaking,
                onSend: {
                    viewModel.streamMessage(
                        model: viewModel.selectedModel,
                        systemPrompt: viewModel.selectedSystemPrompt.text,
                        attachedImages: viewModel.attachedImagesData
                    )
                },
                onStop: { viewModel.stopMessageStreaming() },
                onToggleMic: { viewModel.toggleMic() },
                onToggleVAD: { viewModel.toggleVADMode() },
                onToggleTTS: { viewModel.toggleTTS() },
                onStopSpeaking: { viewModel.stopSpeaking() },
                onOpenTTSSettings: { showTTSSettings = true },  // ✅ NEW
                onImportImages: { images in viewModel.attachedImages.append(contentsOf: images) }
            )
            .padding()
            .background {
                KeyboardMonitor {
                    if !viewModel.vadEnabled {
                        viewModel.toggleMic()
                    }
                }
            }
            .onAppear {
                viewModel.startVAD()
            }
            .onDisappear {
                viewModel.stopVAD()
                viewModel.stopSpeaking()
            }
        }
        .navigationTitle(viewModel.currentChatTitle)
        .onAppear {
            viewModel.startVAD()
        }
        .onDisappear {
            viewModel.stopVAD()
        }
    }
}
