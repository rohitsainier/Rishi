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
    @State private var showRawHTML = false
    @State private var showRawSVG = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 👽 Sender + Copy
            HStack {
                Text(message.sender == .assistant ? "👽 Assistant" : "🧑 You")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .bold()

                Spacer()

                Button {
                    let cleanText = extractCleanMessage(from: message.content)
                    copyToClipboard(cleanText)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(showCopied ? .green : .primary)
                        .imageScale(.medium)
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Copy response to clipboard")
            }

            // 🌐 HTML
            if let html = extractedHTML {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Preview HTML", isOn: $showRawHTML)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Group {
                        if !showRawHTML {
                            ScrollView {
                                Text(html)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(12)
                            }
                            .frame(maxHeight: 300)
                        } else {
                            RichWebView(html: html, height: $htmlHeight)
                                .frame(height: min(400, max(100, htmlHeight)))
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                        }
                    }
                }
            }

            // 🖼 SVG
            else if let svg = extractedSVG {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Preview SVG", isOn: $showRawSVG)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Group {
                        if !showRawSVG {
                            ScrollView {
                                Text(svg)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(12)
                            }
                            .frame(maxHeight: 300)
                        } else {
                            ResizableSVGWebView(svg: svg, height: $svgHeight, width: $svgWidth)
                                .frame(width: svgWidth, height: svgHeight)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                        }
                    }
                }
            }

            // ✍️ Markdown Fallback
            else if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Markdown(message.content)
                    .fontWeight(.regular)
                    .markdownTheme(.docC)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
            }

            // 🖼 Attached Images
            if let images = message.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, img in
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 120)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
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

