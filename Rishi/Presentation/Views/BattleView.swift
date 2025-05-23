//
//  BattleView.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//
import SwiftUI
import Combine

struct BattleView: View {
    @ObservedObject var viewModel: BattleViewModel
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Theme Colors
    private var leftAccentColor: Color { .blue }
    private var rightAccentColor: Color { .orange }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.bottom, 1) // Small separation

            Divider() // Visually separates header from content

            battleArenaView
                .layoutPriority(1) // Takes up available space

            inputAreaView
        }
        .background(Material.regular) // More macOS-like background
        .frame(minWidth: 800, minHeight: 600) // Typical window size
        .task {
            await viewModel.fetchAvailableModels()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Duel Arena")
                    .font(.title2.weight(.semibold))
                Text("Pit two AI models against each other in a battle of wits.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Potentially add a "Clear Battle" or "Settings" button here later
            Button {
                viewModel.leftMessages.removeAll()
                viewModel.rightMessages.removeAll()
                viewModel.promptInput = ""
            } label: {
                Label("New Duel", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(viewModel.isStreaming)
        }
        .padding()
        .background(Material.regular)
    }

    // MARK: - Battle Arena View
    private var battleArenaView: some View {
        HStack(spacing: 0) {
            modelColumnView(
                modelName: $viewModel.selectedLeftModel,
                messages: viewModel.leftMessages,
                accentColor: leftAccentColor,
                side: .left,
                isStreaming: viewModel.isStreaming && !viewModel.rightMessages.isEmpty // Stream indicator only if this side is active
            )
            .padding()

            modelColumnView(
                modelName: $viewModel.selectedRightModel,
                messages: viewModel.rightMessages,
                accentColor: rightAccentColor,
                side: .right,
                isStreaming: viewModel.isStreaming && !viewModel.leftMessages.isEmpty
            )
            .padding()
        }
    }

    // MARK: - Model Column View
    private func modelColumnView(
        modelName: Binding<String>,
        messages: [ChatMessage],
        accentColor: Color,
        side: BattleSide,
        isStreaming: Bool
    ) -> some View {
        VStack(spacing: 0) {
            modelHeader(modelName: modelName, accentColor: accentColor)
            responseArea(messages: messages, accentColor: accentColor, modelDisplayName: modelName.wrappedValue)
            
            if !messages.isEmpty && !viewModel.isStreaming {
                // Show vote button only if there are messages and not streaming
                voteButton(for: side, modelName: modelName.wrappedValue, accentColor: accentColor)
                    .padding(.vertical)
            }
        }
        .overlay(
            isStreaming ?
            AnyView(AnimatedBorderView(accentColor: accentColor)) :
            AnyView(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(0.4), lineWidth: 2)
                    .padding(1)
            )
        )
    }

    // MARK: - Animated Border View
    private struct AnimatedBorderView: View {
        let accentColor: Color
        @State private var animationProgress: CGFloat = 0
        
        var body: some View {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: accentColor.opacity(0.1), location: 0.0),
                            .init(color: accentColor.opacity(0.2), location: 0.1),
                            .init(color: accentColor.opacity(0.3), location: 0.3),
                            .init(color: accentColor.opacity(0.4), location: 0.5),
                            .init(color: accentColor.opacity(0.5), location: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(animationProgress * 360),
                        endAngle: .degrees((animationProgress * 360) + 360.0)
                    ),
                    lineWidth: 2
                )
                .padding(1)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        animationProgress = 1.0
                    }
                }
        }
    }

    // MARK: - Model Header
    private func modelHeader(modelName: Binding<String>, accentColor: Color) -> some View {
        HStack {
            // Use a generic icon or model-specific one if available
            Image(systemName: modelName.wrappedValue.contains("GPT") ? "brain.head.profile" : (modelName.wrappedValue.contains("Claude") ? "bubble.left.and.bubble.right" : "cpu"))
                .foregroundColor(accentColor)
                .font(.title3)

            Picker(modelName.wrappedValue, selection: modelName) {
                ForEach(viewModel.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu) // Or .popUpButton for a more classic macOS feel
            .labelsHidden()
            .frame(minWidth: 150) // Ensure picker has enough space

            Spacer()
        }
        .padding()
        .background(Material.ultraThin) // Slightly different material for header within column
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)), alignment: .bottom) // Subtle divider
    }
    
    // MARK: - Response Area
    private func responseArea(messages: [ChatMessage], accentColor: Color, modelDisplayName: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        if viewModel.isStreaming {
                            VStack {
                                ProgressView()
                                    .padding(.bottom, 5)
                                Text("\(modelDisplayName) is thinking...")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding()
                        } else {
                            emptyStateView(modelName: modelDisplayName)
                        }
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure content aligns left
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy: proxy, messages: messages) }
            .onChange(of: messages.last?.content) { _, _ in scrollToBottom(proxy: proxy, messages: messages) }
        }
        .frame(maxHeight: .infinity) // Allow it to grow
    }

    private func scrollToBottom(proxy: ScrollViewProxy, messages: [ChatMessage]) {
        if let lastId = messages.last?.id {
            withAnimation(.spring(duration: 0.3)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    private func emptyStateView(modelName: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill") // More thematic icon
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Responses from \(modelName) will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
        .padding(40)
    }

    // MARK: - Vote Button
    private func voteButton(for side: BattleSide, modelName: String, accentColor: Color) -> some View {
        Button {
            viewModel.vote(winnerModel: modelName)
        } label: {
            Label("Declare \(modelName) Winner", systemImage: "crown.fill")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(.plain) // Removes default button chrome to let our background shine
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        .disabled(viewModel.isStreaming)
    }

    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 8) {
            if viewModel.isStreaming {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI models are generating responses...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            HStack(alignment: .center, spacing: 12) {
                TextField("Ask something...", text: $viewModel.promptInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isStreaming)
                    .onSubmit {
                        Task {
                            await viewModel.performBattle()
                        }
                    }

                battleButton
            }
        }
        .padding()
        .background(Material.regular.shadow(.drop(color: .black.opacity(0.1), radius: 5, y: -2))) // Shadow on top edge
    }

    // MARK: - Battle Button
    private var battleButton: some View {
        Button {
            Task {
                await viewModel.performBattle()
            }
        } label: {
            Label("Send", systemImage: "paperplane.fill")
                .font(.headline)
                .padding(.vertical, 2)
        }
        .buttonStyle(.borderedProminent) // Standard prominent button style
        .tint( (viewModel.promptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming) ? .gray : .accentColor)
        .disabled(viewModel.promptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
    }
}
