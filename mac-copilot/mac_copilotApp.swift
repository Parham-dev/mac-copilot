//
//  mac_copilotApp.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

@main
struct mac_copilotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    SidecarManager.shared.startIfNeeded()
                }
                .onDisappear {
                    SidecarManager.shared.stop()
                }
        }
    }
}
