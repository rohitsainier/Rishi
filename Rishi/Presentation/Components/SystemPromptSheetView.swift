//
//  SystemPromptMenuView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct SystemPromptSheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose a System Prompt")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.groupedPromptCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category)
                                .font(.headline)

                            ForEach(viewModel.groupedSystemPrompts[category] ?? []) { prompt in
                                Button(action: {
                                    viewModel.selectedSystemPrompt = prompt
                                    isPresented = false // ✅ Auto-dismiss after selection
                                }) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: viewModel.selectedSystemPrompt == prompt ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.selectedSystemPrompt == prompt ? .accentColor : .gray)

                                        Text(prompt.text)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}
