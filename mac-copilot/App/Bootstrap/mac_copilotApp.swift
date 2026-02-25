//
//  mac_copilotApp.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

@main
struct mac_copilotApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            OnboardingRootView()
                .environmentObject(appEnvironment)
                .environmentObject(appEnvironment.authViewModel)
                .background(WindowFrameGuard())
        }
        .defaultSize(width: 1040, height: 900)
    }
}
