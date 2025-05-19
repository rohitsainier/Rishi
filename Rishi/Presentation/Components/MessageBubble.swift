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
    @State private var extractedSVG: String?
    @State private var extractedHTML: String?
    @State private var svgHeight: CGFloat = 10
    @State private var svgWidth: CGFloat = 10
    @State private var htmlHeight: CGFloat = 400

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
            // 🧠 SVG WebView rendering (WKWebView-based)
            if let html = extractedHTML {
                RichWebView(html: html, height: $htmlHeight)
                    .frame(height: htmlHeight)
                    .cornerRadius(8)
                    .disabled(true)
            }
            else if let svg = extractedSVG {
                ResizableSVGWebView(svg: svg,
                                    height: $svgHeight,
                                    width: $svgWidth)
                    .frame(width: svgWidth, height: svgHeight)
                    .cornerRadius(8)
                    .disabled(true)
            } else {
                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(message.content)
                        .fontWeight(.bold)
                        .markdownTheme(.docC)
                        .padding(8)
                        .background(message.sender == .user ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // 🖼 Attached Images (non-svg)
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
        .onAppear {
            extractedSVG = extractSVGFromMarkdown(message.content)
            extractedHTML = extractHTMLFromMarkdown(message.content)
        }
        .onChange(of: message.content) {
            extractedSVG = extractSVGFromMarkdown(message.content)
            extractedHTML = extractHTMLFromMarkdown(message.content)
        }
    }
}
