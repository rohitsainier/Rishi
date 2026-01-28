//
//  MessageInputView.swift
//  Rishi
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
    
    // TTS Properties
    let ttsEnabled: Bool
    let isSpeaking: Bool
    
    let onSend: () -> Void
    let onStop: () -> Void
    let onToggleMic: () -> Void
    let onToggleVAD: () -> Void
    let onToggleTTS: () -> Void
    let onStopSpeaking: () -> Void
    let onOpenTTSSettings: () -> Void  // ✅ NEW
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
                
                // Image picker
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
                
                // VAD Visualizer
                if isListening {
                    VADVisualizer(
                        audioLevel: audioLevel,
                        isListening: isListening,
                        isSpeechDetected: isSpeechDetected
                    )
                }
                
                // ✅ TTS Controls Group
                HStack(spacing: 4) {
                    // TTS Toggle
                    Button(action: {
                        onToggleTTS()
                    }) {
                        Image(systemName: ttsEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .foregroundColor(ttsEnabled ? .green : .secondary)
                    }
                    .help(ttsEnabled ? "TTS Enabled" : "TTS Disabled")
                    .buttonStyle(.plain)
                    
                    // ✅ TTS Settings Button
                    Button(action: {
                        onOpenTTSSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .help("TTS Settings")
                    .buttonStyle(.plain)
                    
                    // Stop speaking button
                    if isSpeaking {
                        Button(action: {
                            onStopSpeaking()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                        }
                        .help("Stop Speaking")
                        .buttonStyle(.plain)
                        .transition(.scale)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
                
                // VAD Toggle
                Button(action: {
                    onToggleVAD()
                }) {
                    Image(systemName: vadEnabled ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundColor(vadEnabled ? .green : .secondary)
                }
                .help(vadEnabled ? "VAD Mode (Auto-detect)" : "Manual Mode (Push-to-talk)")
                .buttonStyle(.plain)
                
                // Manual mic button
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
                
                // Send / Stop streaming
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
            
            // Voice Input Status
            HStack(spacing: 8) {
                Text(voiceStatusText)
                    .font(.caption)
                    .foregroundColor(voiceStatusColor)
                
                // Speaking indicator
                if isSpeaking {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.green)
                        Text("Speaking... (speak to interrupt)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Error message
            if let error = voiceErrorMessage {
                Text(error)
                    .foregroundColor(.orange)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSpeaking)
    }
    
    private var voiceStatusText: String {
        if isSpeaking {
            return "🔊 Speaking... (VAD paused)"
        }
        
        if vadEnabled {
            if isListening {
                return isSpeechDetected ? "🎙 Speaking detected..." : "👂 Listening for voice..."
            } else {
                return "🤖 VAD Active - Start speaking"
            }
        } else {
            return isListening
                ? "🎙 Recording..."
                : "⌨ Click mic or press space to speak"
        }
    }
    
    private var voiceStatusColor: Color {
        if isSpeaking { return .orange }
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
