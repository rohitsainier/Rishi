//
//  OllamaError.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noModels

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "❌ Invalid API URL."
        case .invalidResponse:
            return "❌ Could not decode the server response."
        case .noModels:
            return "❌ No models available download atleast one"
        }
    }
}
