//
//  MessageBubble.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopied = false
    @State private var selectedImage: NSImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.sender == .assistant ? "👽" : "You")
                    .bold()

                Spacer()

                if message.sender == .assistant {
                    Button {
                        let cleanText = extractCleanMessage(from: message.content)
                        copyToClipboard(cleanText)

                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        Label("Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .help("Copy response to clipboard")
                    .buttonStyle(.borderless)
                }
            }

            // 🧠 Message content
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Markdown(message.content)
                    .fontWeight(.bold)
                    .markdownTheme(.docC)
                    .padding(8)
                    .background(message.sender == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            // 🖼 Attached Images
            if let images = message.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, img in
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 120)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func extractCleanMessage(from markdown: String) -> String {
        let pattern = #"```(?:\w+)?\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown)),
           let range = Range(match.range(at: 1), in: markdown) {
            return String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

