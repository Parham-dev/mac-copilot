//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: GitHubAuthService
    @State private var chats: [String] = ["New Project", "Landing Page", "CRM Dashboard"]
    @State private var selectedChat: String? = "New Project"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedChat) {
                ForEach(chats, id: \.self) { chat in
                    Label(chat, systemImage: "bubble.left.and.bubble.right")
                        .tag(chat)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .navigationTitle("CopilotForge")
            .toolbar {
                ToolbarItem {
                    Button(action: createChat) {
                        Label("New Chat", systemImage: "plus")
                    }
                    .disabled(!authService.isAuthenticated)
                }

                ToolbarItem {
                    if authService.isAuthenticated {
                        Button("Sign Out") {
                            authService.signOut()
                        }
                    }
                }
            }
        } detail: {
            if !authService.isAuthenticated {
                AuthView()
            } else if let selectedChat {
                ChatView(chatTitle: selectedChat)
            } else {
                ContentUnavailableView("Select a chat", systemImage: "message")
            }
        }
    }

    private func createChat() {
        let title = "Chat \(chats.count + 1)"
        chats.append(title)
        selectedChat = title
    }
}

#Preview {
    ContentView()
}
