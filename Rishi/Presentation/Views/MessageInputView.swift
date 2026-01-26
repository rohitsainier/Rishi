//
//  MessageInputView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//
//

import SwiftUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    @Binding var input: String
    @Binding var isStreaming: Bool
    @Binding var attachedImages: [NSImage]
    
    let isListening: Bool
    let voiceErrorMessage: String?
    let vadEnabled: Bool
    let audioLevel: Float
    let isSpeechDetected: Bool
    
    let onSend: () -> Void
    let onStop: () -> Void
    let onToggleMic: () -> Void
    let onToggleVAD: () -> Void
    let onImportImages: ([NSImage]) -> Void
    
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Ask something...", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                
                if isStreaming {
                    ProgressView().scaleEffect(0.6)
                        .frame(width: 6, height: 6)
                        .padding(.horizontal, 6)
                }
                
                // 🖼 Image picker with count badge
                ZStack(alignment: .topTrailing) {
                    Button {
                        pickImages()
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.plain)
                    .help("Attach image(s)")
                    
                    if !attachedImages.isEmpty {
                        Text("\(attachedImages.count)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color(NSColor.systemRed)))
                            .offset(x: 8, y: -8)
                    }
                }
                
                // 🎙 VAD Visualizer
                if isListening {
                    VADVisualizer(
                        audioLevel: audioLevel,
                        isListening: isListening,
                        isSpeechDetected: isSpeechDetected
                    )
                }
                
                // 🎚 VAD Toggle
                Button(action: {
                    onToggleVAD()
                }) {
                    Image(systemName: vadEnabled ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundColor(vadEnabled ? .green : .secondary)
                }
                .help(vadEnabled ? "VAD Mode (Auto-detect)" : "Manual Mode (Push-to-talk)")
                .buttonStyle(.plain)
                
                // 🎙 Microphone (manual mode only)
                if !vadEnabled {
                    Button(action: {
                        onToggleMic()
                    }) {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .foregroundColor(isListening ? .red : .primary)
                    }
                    .help(isListening ? "Stop Listening" : "Start Voice Input")
                    .buttonStyle(.plain)
                }
                
                // 🚦 Send / Stop streaming
                if isStreaming {
                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
                } else {
                    Button("Send") {
                        onSend()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            // 👂 Voice Input Status
            Text(voiceStatusText)
                .font(.caption)
                .foregroundColor(voiceStatusColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // ⚠️ Show any error
            if let error = voiceErrorMessage {
                Text(error)
                    .foregroundColor(.orange)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
    }
    
    private var voiceStatusText: String {
        if vadEnabled {
            if isListening {
                return isSpeechDetected ? "🎙 Speaking detected..." : "👂 Listening for voice..."
            } else {
                return "🤖 VAD Active - Start speaking to interact"
            }
        } else {
            return isListening
                ? "🎙 Recording... (Click mic or press space to stop)"
                : "⌨ Click mic or press space bar to speak"
        }
    }
    
    private var voiceStatusColor: Color {
        if vadEnabled {
            return isSpeechDetected ? .green : .blue
        }
        return .accentColor
    }
    
    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            let selectedImages = panel.urls.compactMap { NSImage(contentsOf: $0) }
            onImportImages(selectedImages)
        }
    }
}
