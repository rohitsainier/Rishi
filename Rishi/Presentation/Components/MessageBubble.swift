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

    private func extractCleanMessage(from markdown: String) -> String {
        let pattern = #"```(?:\w+)?\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern),
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

    private func extractSVGFromMarkdown(_ markdown: String) -> String? {
        let pattern = #"<svg[\s\S]*?</svg>"#
        if let range = markdown.range(of: pattern, options: .regularExpression) {
            var svg = String(markdown[range])
            if !svg.contains("xmlns=") {
                svg = svg.replacingOccurrences(of: "<svg", with: "<svg xmlns=\"http://www.w3.org/2000/svg\"")
            }
            return svg
        }
        return nil
    }
    
    private func extractHTMLFromMarkdown(_ markdown: String) -> String? {
        let pattern = #"```html\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown)),
           let range = Range(match.range(at: 1), in: markdown) {
            return String(markdown[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
