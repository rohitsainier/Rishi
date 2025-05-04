//
//  SidebarView.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Label("Chat", systemImage: "message")
            Label("Library", systemImage: "books.vertical")
        }
        .frame(minWidth: 200)
    }
}
