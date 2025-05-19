//
//  Helper.swift
//  Rishi
//
//  Created by Rohit Saini on 19/05/25.
//

import SwiftUI
import AVKit

 func extractCleanMessage(from markdown: String) -> String {
    let pattern = #"```(?:\w+)?\n([\s\S]*?)```"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown)),
       let range = Range(match.range(at: 1), in: markdown) {
        return String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
}

 func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

 func extractSVGFromMarkdown(_ markdown: String) -> String? {
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

 func extractHTMLFromMarkdown(_ markdown: String) -> String? {
    let pattern = #"```html\n([\s\S]*?)```"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown)),
       let range = Range(match.range(at: 1), in: markdown) {
        return String(markdown[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return nil
}

 func downloadSVG(svg: String) {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.svg]
    savePanel.nameFieldStringValue = "icon.svg"

    savePanel.begin { result in
        if result == .OK, let url = savePanel.url {
            do {
                try svg.write(to: url, atomically: true, encoding: .utf8)
                print("✅ SVG saved to \(url.path)")
                // Optional: Show alert or badge feedback
            } catch {
                print("❌ Failed to save SVG: \(error)")
            }
        }
    }
}

extension UTType {
    static var svg: UTType {
        UTType(filenameExtension: "svg") ?? .text
    }
}
