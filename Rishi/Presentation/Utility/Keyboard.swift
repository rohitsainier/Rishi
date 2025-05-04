//
//  Keyboard.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//


import SwiftUI
import AppKit

/// A view that listens to global keyboard events
struct KeyboardMonitor: NSViewRepresentable {
    var onSpacebarPressed: () -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onSpacebarPressed = onSpacebarPressed
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {}

    class KeyCatcherView: NSView {
        var onSpacebarPressed: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 49 && !event.modifierFlags.contains(.command) {
                // 49 = spacebar
                onSpacebarPressed?()
            }
        }

        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self) // Ensure we receive keyDown
        }
    }
}
