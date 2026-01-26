////
////  TTSSettingsView.swift
////  Rishi
////
////  Created by Rohit Saini on 26/01/26.
////
//
//import SwiftUI
//
//struct TTSSettingsView: View {
//    @ObservedObject var viewModel: ChatViewModel
//    @Binding var isPresented: Bool
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 20) {
//            HStack {
//                Text("Text-to-Speech Settings")
//                    .font(.title2)
//                    .bold()
//                Spacer()
//                Button {
//                    isPresented = false
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                }
//                .buttonStyle(.borderless)
//            }
//            
//            Divider()
//            
//            // Voice Selection
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Voice")
//                    .font(.headline)
//                
//                Picker("Select Voice", selection: Binding(
//                    get: { viewModel.selectedVoice },
//                    set: { viewModel.setVoice($0) }
//                )) {
//                    ForEach(viewModel.availableVoices, id: \.self) { voice in
//                        Text(voice).tag(voice)
//                    }
//                }
//                .pickerStyle(.menu)
//            }
//            
//            // Speech Rate
//            VStack(alignment: .leading, spacing: 8) {
//                HStack {
//                    Text("Speech Rate")
//                        .font(.headline)
//                    Spacer()
//                    Text(String(format: "%.1fx", viewModel.speechRate))
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                Slider(value: Binding(
//                    get: { viewModel.speechRate },
//                    set: { viewModel.setSpeechRate($0) }
//                ), in: 0.1...1.0, step: 0.1)
//                
//                HStack {
//                    Text("Slow")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    Spacer()
//                    Text("Fast")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//            
//            // Test Button
//            Button {
//                viewModel.ttsService.speak("Hello! This is a test of the text to speech system.")
//            } label: {
//                Label("Test Voice", systemImage: "speaker.wave.2.fill")
//            }
//            .buttonStyle(.borderedProminent)
//            
//            Spacer()
//        }
//        .padding()
//        .frame(minWidth: 400, minHeight: 300)
//    }
//}
