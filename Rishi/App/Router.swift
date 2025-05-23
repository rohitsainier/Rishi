//
//  Router.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

final class AppRouter {
    static let shared = AppRouter()

    private var chatViewModel: ChatViewModel?
    private var battleViewModel: BattleViewModel?
    
    @MainActor
    func rootView() -> some View {
        if chatViewModel == nil {
            chatViewModel = AppDI.makeChatViewModel()
        }
        if battleViewModel == nil {
            battleViewModel = AppDI.makeBattleViewModel()
        }
        let chatViewModel = chatViewModel!
        let bettleViewModel = battleViewModel!

        return NavigationSplitView {
            SidebarView(viewModel: chatViewModel)
        } detail: {
            ChatView(chatViewModel: chatViewModel, battleViewModel: bettleViewModel)
        }
    }
}
