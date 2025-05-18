//
//  SVGWebView.swift
//  Rishi
//
//  Created by Rohit Saini on 19/05/25.
//

import SwiftUI
import WebKit

struct ResizableSVGWebView: NSViewRepresentable {
    let svg: String
    @Binding var height: CGFloat
    @Binding var width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.load(svg: svg, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(svg: svg, in: webView)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ResizableSVGWebView
        private var lastLoadedSVG: String?

        init(parent: ResizableSVGWebView) {
            self.parent = parent
        }

        func load(svg: String, in webView: WKWebView) {
            guard svg != lastLoadedSVG else { return }
            lastLoadedSVG = svg
            webView.loadHTMLString(wrappedHTML(svg), baseURL: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function() {
                var rect = document.querySelector('svg').getBoundingClientRect();
                return { width: rect.width, height: rect.height };
            })();
            """

            webView.evaluateJavaScript(js) { result, error in
                if let dict = result as? [String: Any],
                   let newHeight = dict["height"] as? Double,
                   let newWidth = dict["width"] as? Double {
                    DispatchQueue.main.async {
                        self.parent.height = CGFloat(newHeight)
                        self.parent.width = CGFloat(newWidth)
                    }
                } else {
                    print("❌ Failed to evaluate SVG size JS: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }

        private func wrappedHTML(_ svg: String) -> String {
            """
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                html, body {
                  margin: 0;
                  padding: 0;
                  background: transparent;
                  overflow: hidden;
                }
                svg {
                  display: block;
                  margin: auto;
                }
              </style>
            </head>
            <body>
              \(svg)
            </body>
            </html>
            """
        }
    }
}
