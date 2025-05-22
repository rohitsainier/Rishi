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
        List(selection: Binding(
            get: { viewModel.activeScreen == .chat ? viewModel.currentChatId : nil },
            set: { newId in
                if let newId = newId {
                    viewModel.selectChat(id: newId)
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
                    .tag(history.id)
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

            Section(header: Text("Experiments")) {
                Button {
                    viewModel.activeScreen = .battle
                } label: {
                    Label("Model Battle", systemImage: "bolt.circle")
                        .font(.headline)
                }
                .buttonStyle(.plain)
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
