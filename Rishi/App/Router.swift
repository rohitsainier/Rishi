//
//  Router.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

final class AppRouter {
    static let shared = AppRouter()

    private var sharedViewModel: ChatViewModel?

    @MainActor
    func rootView() -> some View {
        if sharedViewModel == nil {
            sharedViewModel = AppDI.makeChatViewModel()
        }

        let viewModel = sharedViewModel!

        return NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ChatView(viewModel: viewModel)
        }
    }
}
