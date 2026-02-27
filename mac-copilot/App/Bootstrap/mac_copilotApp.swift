//
//  mac_copilotApp.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI
import FactoryKit

@main
struct mac_copilotApp: App {
    @StateObject private var appEnvironment = Container.shared.appEnvironment()

    init() {
        SentryMonitoring.start()
    }

    var body: some Scene {
        WindowGroup {
            OnboardingRootView()
                .environmentObject(appEnvironment)
                .environmentObject(appEnvironment.authEnvironment.authViewModel)
                .environmentObject(appEnvironment.shellViewModel)
                .environmentObject(appEnvironment.featureRegistry)
                .environmentObject(appEnvironment.projectsEnvironment)
                .environmentObject(appEnvironment.projectsShellBridge)
                .environmentObject(appEnvironment.companionEnvironment)
                .background(WindowFrameGuard())
        }
        .defaultSize(width: 1060, height: 900)
    }
}
