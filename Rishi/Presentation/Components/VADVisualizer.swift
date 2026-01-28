//
//  VADVisualizer.swift
//  Rishi
//
//  VAD Audio Level Visualizer
//


import SwiftUI

struct VADVisualizer: View {
    let audioLevel: Float
    let isListening: Bool
    let isSpeechDetected: Bool
    var isPaused: Bool = false  // ✅ NEW: Optional paused state
    
    private var normalizedLevel: CGFloat {
        let minDB: Float = -60.0
        let maxDB: Float = -10.0
        let clamped = max(minDB, min(maxDB, audioLevel))
        return CGFloat((clamped - minDB) / (maxDB - minDB))
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: normalizedLevel)
            }
        }
        .frame(height: 20)
        .opacity(isPaused ? 0.4 : 1.0)  // ✅ Dim when paused
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        // ✅ Show minimal bars when paused
        if isPaused {
            return 4
        }
        
        let threshold = CGFloat(index) / 5.0
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        
        if normalizedLevel > threshold {
            return baseHeight + (maxHeight - baseHeight) * normalizedLevel
        }
        return baseHeight
    }
    
    private func barColor(for index: Int) -> Color {
        // ✅ Show orange when paused
        if isPaused {
            return .orange.opacity(0.5)
        }
        
        if !isListening {
            return .gray.opacity(0.3)
        }
        
        if isSpeechDetected {
            return .green
        }
        
        let threshold = CGFloat(index) / 5.0
        if normalizedLevel > threshold {
            return .blue
        }
        return .gray.opacity(0.5)
    }
}
