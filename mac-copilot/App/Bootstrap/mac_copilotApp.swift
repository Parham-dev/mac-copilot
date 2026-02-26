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
                .environmentObject(appEnvironment.shellEnvironment)
                .environmentObject(appEnvironment.companionEnvironment)
                .background(WindowFrameGuard())
        }
        .defaultSize(width: 920, height: 900)
    }
}
