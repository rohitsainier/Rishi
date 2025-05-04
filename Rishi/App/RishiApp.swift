//
//  RishiApp.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import SwiftUI

@main
struct RishiApp: App {
    var body: some Scene {
        WindowGroup {
            AppRouter.shared.rootView()
        }
    }
}

