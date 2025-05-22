//
//  BattleView.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//

import SwiftUI

// Extension to make TextEditor display a placeholder
extension TextEditor {
    func placeholder<Content: View>(_ view: Content, when shouldShow: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            view.opacity(shouldShow ? 1 : 0)
            if shouldShow {
                self
            }
        }
    }
}

struct BattleView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var promptInput = ""
    @State private var leftResponse = ""
    @State private var rightResponse = ""
    @State private var isStreaming = false
    @State private var selectedLeftModel: String = "gemma3:4b"
    @State private var selectedRightModel: String = "gemma3:12b"

    var body: some View {
        NavigationView { // Use NavigationView for title and potential toolbar items
            VStack(spacing: 20) {
                // Title
                Text("🤺 Model Battle")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 5)

                // Model Comparison Section
                HStack(alignment: .top, spacing: 15) {
                    // Left Model
                    modelResponseCard(
                        modelName: $selectedLeftModel,
                        responseText: $leftResponse,
                        isLeft: true,
                        isStreaming: isStreaming
                    )
                    .frame(maxWidth: .infinity)

                    // Right Model
                    modelResponseCard(
                        modelName: $selectedRightModel,
                        responseText: $rightResponse,
                        isLeft: false,
                        isStreaming: isStreaming
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                // Prompt Input
                HStack {
                    TextField("Enter your prompt...", text: $promptInput)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                        .disabled(isStreaming) // Disable input during streaming
                }
                .padding(.horizontal)

                // Action Button (Battle / Streaming)
                if isStreaming {
                    ProgressView("Streaming responses...")
                        .progressViewStyle(.circular)
                        .padding()
                        .transition(.opacity) // Smooth transition
                } else {
                    Button {
                        Task {
                            await performBattle()
                        }
                    } label: {
                        Text("Battle!")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(promptInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.availableModels.count < 2 ? Color.gray.opacity(0.5) : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(promptInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.availableModels.count < 2)
                    .padding(.horizontal)
                    .transition(.opacity) // Smooth transition
                }

                // Voting Buttons
                if !leftResponse.isEmpty && !rightResponse.isEmpty && !isStreaming {
                    HStack(spacing: 20) {
                        VoteButton(label: "Left Wins", color: .green) { vote(winner: selectedLeftModel) }
                        VoteButton(label: "Right Wins", color: .blue) { vote(winner: selectedRightModel) }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: isStreaming) // Apply animation to state changes
            
        }
        .onAppear {
            // Ensure selected models are valid, or set defaults if available
            if viewModel.availableModels.count > 0 {
                if !viewModel.availableModels.contains(selectedLeftModel) {
                    selectedLeftModel = viewModel.availableModels.first ?? "gemma3:4b"
                }
                if viewModel.availableModels.count > 1 && !viewModel.availableModels.contains(selectedRightModel) {
                    selectedRightModel = viewModel.availableModels[1] // Use second model as default if available
                } else if viewModel.availableModels.count == 1 {
                    selectedRightModel = viewModel.availableModels.first! // Fallback if only one model
                } else if viewModel.availableModels.isEmpty {
                    selectedRightModel = "gemma3:12b" // Fallback if no models
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func modelResponseCard(modelName: Binding<String>, responseText: Binding<String>, isLeft: Bool, isStreaming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Model", selection: modelName) {
                ForEach(viewModel.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .font(.headline)
            .tint(isLeft ? .purple : .orange) // Distinct tint for each picker

            ZStack(alignment: .topLeading) { // Used for placeholder
                if responseText.wrappedValue.isEmpty {
                    Text(isStreaming ? "Generating response..." : "Model response will appear here.")
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                        .allowsHitTesting(false) // Allows clicks to pass through to TextEditor
                }

                TextEditor(text: responseText)
                    .font(.body)
                    .frame(minHeight: 180, maxHeight: .infinity)
                    .scrollContentBackground(.hidden) // Make TextEditor background transparent
                    .background(Color.clear)
                    .disabled(true) // Make TextEditor read-only
            }
        }
        .padding()
        .background(Color.clear) // Clear background for the whole card
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.primary.opacity(0.05)) // Subtle background fill
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2) // Soft shadow
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isStreaming ? (isLeft ? Color.purple : Color.orange) : Color.gray.opacity(0.3), lineWidth: isStreaming ? 2 : 1) // Highlight border when streaming
                )
        )
        .padding(.vertical, 5) // Add some vertical padding for the card itself
    }

    // MARK: - Action Functions

    func performBattle() async {
        isStreaming = true
        leftResponse = ""
        rightResponse = ""

        let userMessage = ChatMessage(sender: .user, content: promptInput)

        await withTaskGroup(of: Void.self) { group in
            // Task for the left model
            group.addTask {
                do {
                    print("📡 Starting LEFT stream: \(await selectedLeftModel)")
                    let stream = try await viewModel.chatService.sendStream(
                        messages: [userMessage],
                        model: selectedLeftModel,
                        systemPrompt: nil,
                        attachedImages: []
                    )
                    for try await token in stream {
                        await MainActor.run {
                            leftResponse += token
                        }
                    }
                } catch {
                    print("❌ LEFT battle error: \(error)")
                    await MainActor.run {
                        leftResponse = "Error from \(selectedLeftModel): \(error.localizedDescription)"
                    }
                }
            }

            // Task for the right model
            group.addTask {
                do {
                    print("📡 Starting RIGHT stream: \(await selectedRightModel)")
                    let stream = try await viewModel.chatService.sendStream(
                        messages: [userMessage],
                        model: selectedRightModel,
                        systemPrompt: nil,
                        attachedImages: []
                    )
                    for try await token in stream {
                        await MainActor.run {
                            rightResponse += token
                        }
                    }
                } catch {
                    print("❌ RIGHT battle error: \(error)")
                    await MainActor.run {
                        rightResponse = "Error from \(selectedRightModel): \(error.localizedDescription)"
                    }
                }
            }
        }
        isStreaming = false
    }

    func vote(winner: String) {
        print("✅ Voted for: \(winner)")
        // TODO: Implement actual voting logic (e.g., save to UserDefaults or a database)
        // For now, clear responses for a new battle.
        promptInput = ""
        leftResponse = ""
        rightResponse = ""
    }
}

// MARK: - Reusable Vote Button Component

struct VoteButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: "hand.thumbsup.fill")
                .font(.headline)
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(color.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain) // Use .plain to remove default button styling
    }
}
