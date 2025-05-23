//
//  SidebarView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        List(selection: Binding<Set<String>>(
            get: {
                if viewModel.activeScreen == .chat, let chatId = viewModel.currentChatId {
                    return [chatId.uuidString]
                } else if viewModel.activeScreen == .battle {
                    return ["battle"]
                }
                return []
            },
            set: { newSelection in
                guard let selectedId = newSelection.first else { return }
                
                if selectedId == "battle" {
                    viewModel.activeScreen = .battle
                } else if let uuid = UUID(uuidString: selectedId) {
                    viewModel.selectChat(id: uuid)
                    viewModel.activeScreen = .chat
                }
            }
        )) {
            Section(header: Text("Chats")) {
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
                    .tag(history.id.uuidString)
                    .contentShape(Rectangle()) // Make the whole row clickable
                    .contextMenu {
                        Button("Regenerate Title") {
                            Task {
                                await viewModel.generateTitleForChat(id: history.id)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Features")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Battle")
                            .font(.headline)
                        Text("Compare models")
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        viewModel.activeScreen = .battle
                    } label: {
                        Image(systemName: "figure.archery")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .tag("battle")
                .contentShape(Rectangle()) // Make the whole row clickable
            }
        }
        .toolbar {
            Button(action: {
                _ = viewModel.createNewChat()
                viewModel.activeScreen = .chat
            }) {
                Label("New Chat", systemImage: "plus")
            }
        }
        .frame(minWidth: 250)
    }
}
