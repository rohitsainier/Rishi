//
//  SystemPrompt.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

struct SystemPrompt: Identifiable, Hashable {
    var id: String { text }
    let text: String
    let category: String
}
