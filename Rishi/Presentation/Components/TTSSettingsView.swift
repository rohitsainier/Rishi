//
//  TTSSettingsView.swift
//  Rishi
//
//  TTS Settings Panel
//

import SwiftUI

struct TTSSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    
    @State private var localRate: Float
    @State private var localPitch: Float
    @State private var localVolume: Float
    @State private var localVoice: String
    
    init(viewModel: ChatViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        
        // Initialize local state from view model
        _localRate = State(initialValue: viewModel.speechRate)
        _localPitch = State(initialValue: viewModel.pitch)
        _localVolume = State(initialValue: viewModel.volume)
        _localVoice = State(initialValue: viewModel.selectedVoice)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Voice Selection
                    voiceSection
                    
                    Divider()
                    
                    // Speed Control
                    speedSection
                    
                    Divider()
                    
                    // Pitch Control
                    pitchSection
                    
                    Divider()
                    
                    // Volume Control
                    volumeSection
                    
                    Divider()
                    
                    // Preview Button
                    previewSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 400, height: 550)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "speaker.wave.3.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("Text-to-Speech Settings")
                .font(.headline)
            
            Spacer()
            
            // TTS Enable Toggle
            Toggle("", isOn: Binding(
                get: { viewModel.ttsEnabled },
                set: { viewModel.ttsEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding()
    }
    
    // MARK: - Voice Section
    
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice", systemImage: "person.wave.2")
                .font(.headline)
            
            Picker("Voice", selection: $localVoice) {
                ForEach(viewModel.availableVoices, id: \.self) { voice in
                    Text(voice)
                        .tag(voice)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .onChange(of: localVoice) { _, newValue in
                viewModel.setVoice(newValue)
            }
            
            Text("⭐️ indicates enhanced quality voices")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Speed Section
    
    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Speed", systemImage: "speedometer")
                    .font(.headline)
                
                Spacer()
                
                Text(speedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: $localRate, in: 0...1, step: 0.1)
                    .onChange(of: localRate) { _, newValue in
                        viewModel.setSpeechRate(newValue)
                    }
                
                Image(systemName: "hare.fill")
                    .foregroundColor(.secondary)
            }
            
            // Speed presets
            HStack(spacing: 8) {
                SpeedPresetButton(title: "Slow", value: 0.25, currentValue: $localRate) {
                    viewModel.setSpeechRate(0.25)
                }
                SpeedPresetButton(title: "Normal", value: 0.5, currentValue: $localRate) {
                    viewModel.setSpeechRate(0.5)
                }
                SpeedPresetButton(title: "Fast", value: 0.75, currentValue: $localRate) {
                    viewModel.setSpeechRate(0.75)
                }
                SpeedPresetButton(title: "Faster", value: 1.0, currentValue: $localRate) {
                    viewModel.setSpeechRate(1.0)
                }
            }
        }
    }
    
    private var speedDescription: String {
        switch localRate {
        case 0..<0.3: return "Slow"
        case 0.3..<0.6: return "Normal"
        case 0.6..<0.85: return "Fast"
        default: return "Very Fast"
        }
    }
    
    // MARK: - Pitch Section
    
    private var pitchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Pitch", systemImage: "waveform.path")
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.1fx", localPitch))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            
            HStack(spacing: 12) {
                Text("Low")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $localPitch, in: 0.5...2.0, step: 0.1)
                    .onChange(of: localPitch) { _, newValue in
                        viewModel.setPitch(newValue)
                    }
                
                Text("High")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Pitch presets
            HStack(spacing: 8) {
                PitchPresetButton(title: "Deep", value: 0.75, currentValue: $localPitch) {
                    viewModel.setPitch(0.75)
                }
                PitchPresetButton(title: "Normal", value: 1.0, currentValue: $localPitch) {
                    viewModel.setPitch(1.0)
                }
                PitchPresetButton(title: "High", value: 1.25, currentValue: $localPitch) {
                    viewModel.setPitch(1.25)
                }
            }
        }
    }
    
    // MARK: - Volume Section
    
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.2")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(localVolume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: $localVolume, in: 0...1, step: 0.1)
                    .onChange(of: localVolume) { _, newValue in
                        viewModel.setVolume(newValue)
                    }
                
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                viewModel.previewVoice()
            }) {
                HStack {
                    Image(systemName: viewModel.isSpeaking ? "stop.fill" : "play.fill")
                    Text(viewModel.isSpeaking ? "Stop Preview" : "Preview Voice")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.ttsEnabled)
            
            if viewModel.isSpeaking {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Playing preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("Reset to Defaults") {
                resetToDefaults()
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button("Done") {
                viewModel.saveTTSSettings()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func resetToDefaults() {
        localRate = 0.5
        localPitch = 1.0
        localVolume = 1.0
        
        viewModel.setSpeechRate(0.5)
        viewModel.setPitch(1.0)
        viewModel.setVolume(1.0)
        
        // Reset to default voice
        if let defaultVoice = viewModel.availableVoices.first(where: { $0.contains("Rishi") }) ?? viewModel.availableVoices.first {
            localVoice = defaultVoice
            viewModel.setVoice(defaultVoice)
        }
    }
}

// MARK: - Preset Buttons

struct SpeedPresetButton: View {
    let title: String
    let value: Float
    @Binding var currentValue: Float
    let action: () -> Void
    
    private var isSelected: Bool {
        abs(currentValue - value) < 0.05
    }
    
    var body: some View {
        Button(action: {
            currentValue = value
            action()
        }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
    }
}

struct PitchPresetButton: View {
    let title: String
    let value: Float
    @Binding var currentValue: Float
    let action: () -> Void
    
    private var isSelected: Bool {
        abs(currentValue - value) < 0.05
    }
    
    var body: some View {
        Button(action: {
            currentValue = value
            action()
        }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
    }
}



