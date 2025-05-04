//
//  ChatView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
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
        .onChange(of: viewModel.currentChatId) { _, newId in
            // Reset transient states
            activeChatId = newId
            viewModel.currentInput = ""
            viewModel.transcribedText = ""
            viewModel.attachedImages.removeAll()
            viewModel.cancelStreamingIfNeeded()
        }
        .onAppear {
            activeChatId = viewModel.currentChatId
        }
        .task {
            await viewModel.fetchAvailableModels()
        }
    }
}
