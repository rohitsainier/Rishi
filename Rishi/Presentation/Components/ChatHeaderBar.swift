//
//  ChatHeaderBar.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct ChatHeaderBar: View {
    @Binding var showModelPicker: Bool
    @Binding var showChatTypePicker: Bool
    let selectedModel: String
    let selectedChatType: String

    var body: some View {
        HStack {
            Button(action: { showChatTypePicker.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.wave.2.fill")
                    Text(selectedChatType)
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                }
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { showModelPicker.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "globe.central.south.asia.fill")
                    Text(selectedModel)
                        .font(.system(size: 15, weight: .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                }
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}
