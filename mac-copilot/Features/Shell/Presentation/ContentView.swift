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
            sidebarList
            .navigationSplitViewColumnWidth(min: 160, ideal: 210)
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
            detailContent
        }
        .onChange(of: shellViewModel.selectedItem) { _, newValue in
            shellViewModel.didSelectSidebarItem(newValue)
        }
        .alert("Could not create project", isPresented: projectCreationAlertBinding) {
            Button("OK", role: .cancel) {
                projectCreationError = nil
            }
        } message: {
            Text(projectCreationError ?? "Unknown error")
        }
    }

    private var sidebarList: some View {
        List(selection: $shellViewModel.selectedItem) {
            workspaceSection
            projectsSection

            if authViewModel.isAuthenticated {
                signOutSection
            }
        }
    }

    private var workspaceSection: some View {
        Section("Workspace") {
            Label("Profile", systemImage: "person.crop.circle")
                .tag(ShellViewModel.SidebarItem.profile)
        }
    }

    private var projectsSection: some View {
        Section {
            ForEach(shellViewModel.projects) { project in
                projectDisclosure(project)
            }
        } header: {
            projectsHeader
        }
    }

    private var signOutSection: some View {
        Section {
            Button {
                authViewModel.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var projectsHeader: some View {
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

    private func projectDisclosure(_ project: ProjectRef) -> some View {
        DisclosureGroup(isExpanded: projectExpandedBinding(for: project.id)) {
            ForEach(shellViewModel.chats(for: project.id)) { chat in
                Label(chat.title, systemImage: "bubble.left.and.bubble.right")
                    .tag(ShellViewModel.SidebarItem.chat(project.id, chat.id))
            }
        } label: {
            projectLabelRow(project)
        }
    }

    private func projectLabelRow(_ project: ProjectRef) -> some View {
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

            if shellViewModel.activeProjectID == project.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if !authViewModel.isAuthenticated {
            AuthView()
        } else if let selectedItem = shellViewModel.selectedItem {
            switch selectedItem {
            case .profile:
                ProfileView(viewModel: appEnvironment.sharedProfileViewModel())
            case .chat(let projectID, let selectedChatID):
                chatDetailContent(projectID: projectID, selectedChatID: selectedChatID)
            }
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }

    @ViewBuilder
    private func chatDetailContent(projectID: UUID, selectedChatID: UUID) -> some View {
        if let activeProject = shellViewModel.project(for: projectID),
           let selectedChat = shellViewModel.chat(for: selectedChatID, in: projectID) {
            let chatViewModel = appEnvironment.chatViewModel(for: selectedChat, project: activeProject)

            HSplitView {
                ChatView(viewModel: chatViewModel)
                    .frame(minWidth: 300, idealWidth: 470)

                ContextPaneView(
                    shellViewModel: shellViewModel,
                    project: activeProject,
                    previewResolver: appEnvironment.sharedPreviewResolver(),
                    previewRuntimeManager: appEnvironment.sharedPreviewRuntimeManager(),
                    onFixLogsRequest: { prompt in
                        Task {
                            await chatViewModel.send(prompt: prompt)
                        }
                    }
                )
                .frame(minWidth: 300, idealWidth: 470)
            }
        } else if shellViewModel.project(for: projectID) == nil {
            ContentUnavailableView("Select a project", systemImage: "folder")
        } else {
            ContentUnavailableView("Select a chat", systemImage: "message")
        }
    }

    private func projectExpandedBinding(for projectID: UUID) -> Binding<Bool> {
        Binding(
            get: { shellViewModel.isProjectExpanded(projectID) },
            set: { shellViewModel.setProjectExpanded(projectID, isExpanded: $0) }
        )
    }

    private var projectCreationAlertBinding: Binding<Bool> {
        Binding(
            get: { projectCreationError != nil },
            set: { shouldShow in
                if !shouldShow {
                    projectCreationError = nil
                }
            }
        )
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
