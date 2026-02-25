//
//  mac_copilotApp.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

@main
struct mac_copilotApp: App {
    @StateObject private var authService = GitHubAuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .task {
                    SidecarManager.shared.startIfNeeded()
                    await authService.restoreSessionIfNeeded()
                }
                .onDisappear {
                    SidecarManager.shared.stop()
                }
        }
    }
}
