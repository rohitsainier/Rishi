//
//  SidebarView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct ChatHistorySidebar: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        List(selection: $viewModel.currentChatId) {
            ForEach(viewModel.chatHistories, id: \.id) { history in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(history.name)
                            .font(.headline)
                        Text(history.createdAt, style: .date)
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        viewModel.deleteChat(id: history.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .tag(history.id)
                .contentShape(Rectangle()) // Make entire cell tappable
                .contextMenu {
                    Button("Regenerate Title") {
                        Task {
                            await viewModel.generateTitleForChat(id: history.id)
                        }
                    }
                }
            }
        }
        .toolbar {
            Button(action: {
                _ = viewModel.createNewChat()
            }) {
                Label("New Chat", systemImage: "plus")
            }
        }
        .frame(minWidth: 250)
    }
}
