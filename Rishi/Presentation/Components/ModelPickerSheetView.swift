//
//  ModelPickerSheetView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct ModelPickerSheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose a Model")
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
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Button(action: {
                            viewModel.selectedModel = model
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: model == viewModel.selectedModel ?
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundColor(model == viewModel.selectedModel ?
                                                     .accentColor : .gray)
                                Text(model)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(model == viewModel.selectedModel
                                          ? Color.accentColor.opacity(0.1)
                                          : Color.gray.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
