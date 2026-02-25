//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject var shellViewModel: ShellViewModel
    @State private var projectCreationError: String?

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

                Section {
                    ForEach(shellViewModel.projects) { project in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { shellViewModel.isProjectExpanded(project.id) },
                                set: { shellViewModel.setProjectExpanded(project.id, isExpanded: $0) }
                            )
                        ) {
                            ForEach(shellViewModel.chats(for: project.id), id: \.self) { chat in
                                Label(chat, systemImage: "bubble.left.and.bubble.right")
                                    .tag(ShellViewModel.SidebarItem.chat(project.id, chat))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Label(project.name, systemImage: "folder")
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        shellViewModel.selectProject(project.id)
                                    }

                                Spacer()

                                Menu {
                                    Button {
                                        shellViewModel.createChat(in: project.id)
                                    } label: {
                                        Label("New Chat", systemImage: "plus.bubble")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18, alignment: .center)
                                }
                                .menuIndicator(.hidden)
                                .menuStyle(.borderlessButton)
                                .fixedSize()

                                if shellViewModel.activeProjectID == project.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Button {
                            createProjectWithFolderBrowser()
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(.secondary)
                                .frame(width: 18, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
                        .help("Add New Project")
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
                    Button(action: shellViewModel.createChatInActiveProject) {
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
                case .chat(let projectID, let selectedChat):
                    if let activeProject = shellViewModel.project(for: projectID) {
                        VStack(spacing: 0) {
                            activeProjectHeader(activeProject)
                            Divider()

                            HSplitView {
                                ChatView(viewModel: appEnvironment.chatViewModel(for: selectedChat, project: activeProject))
                                    .frame(idealWidth: 760)
                                    .layoutPriority(1)

                                ContextPaneView(shellViewModel: shellViewModel, project: activeProject)
                                    .frame(idealWidth: 420)
                            }
                        }
                    } else {
                        ContentUnavailableView("Select a project", systemImage: "folder")
                    }
                }
            } else {
                ContentUnavailableView("Select a chat", systemImage: "message")
            }
        }
        .onChange(of: shellViewModel.selectedItem) { _, newValue in
            shellViewModel.didSelectSidebarItem(newValue)
        }
        .alert("Could not create project", isPresented: Binding(
            get: { projectCreationError != nil },
            set: { shouldShow in
                if !shouldShow {
                    projectCreationError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                projectCreationError = nil
            }
        } message: {
            Text(projectCreationError ?? "Unknown error")
        }
    }

    @ViewBuilder
    private func activeProjectHeader(_ project: ProjectRef) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                Text(project.localPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func createProjectWithFolderBrowser() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = false
        panel.isExtensionHidden = true
        panel.nameFieldStringValue = "New Project"
        panel.title = "Create New Project"
        panel.prompt = "Create"
        panel.message = "Choose where the new project folder should be created."

        let response = panel.runModal()
        guard response == .OK, let targetURL = panel.url else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            shellViewModel.addProject(name: targetURL.lastPathComponent, localPath: targetURL.path)
        } catch {
            projectCreationError = error.localizedDescription
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ContentView(shellViewModel: environment.shellViewModel)
        .environmentObject(environment)
        .environmentObject(environment.authViewModel)
}
