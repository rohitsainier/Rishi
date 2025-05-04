//
//  Router.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

final class AppRouter {
    static let shared = AppRouter()
    
    @MainActor
    func rootView() -> some View {
        NavigationView {
            SidebarView()
            ChatView(viewModel: AppDI.makeChatViewModel())
        }
    }
}
