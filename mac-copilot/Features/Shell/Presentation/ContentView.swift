//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject var shellViewModel: ShellViewModel

    init(shellViewModel: ShellViewModel) {
        self.shellViewModel = shellViewModel
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $shellViewModel.selectedItem) {
                Section("Workspace") {
                    Label("Profile", systemImage: "person.crop.circle")
                        .tag(ShellViewModel.SidebarItem.profile)
                }

                Section("Chats") {
                    ForEach(shellViewModel.chats, id: \.self) { chat in
                        Label(chat, systemImage: "bubble.left.and.bubble.right")
                            .tag(ShellViewModel.SidebarItem.chat(chat))
                    }
                }

                if authViewModel.isAuthenticated {
                    Section {
                        Button {
                            authViewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .navigationTitle("CopilotForge")
            .toolbar {
                ToolbarItem {
                    Button(action: shellViewModel.createChat) {
                        Label("New Chat", systemImage: "plus")
                    }
                    .disabled(!authViewModel.isAuthenticated)
                }
            }
        } detail: {
            if !authViewModel.isAuthenticated {
                AuthView()
            } else if let selectedItem = shellViewModel.selectedItem {
                switch selectedItem {
                case .profile:
                    ProfileView(viewModel: appEnvironment.sharedProfileViewModel())
                case .chat(let selectedChat):
                    ChatView(viewModel: appEnvironment.chatViewModel(for: selectedChat))
                }
            } else {
                ContentUnavailableView("Select a chat", systemImage: "message")
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ContentView(shellViewModel: environment.shellViewModel)
        .environmentObject(environment)
        .environmentObject(environment.authViewModel)
}
