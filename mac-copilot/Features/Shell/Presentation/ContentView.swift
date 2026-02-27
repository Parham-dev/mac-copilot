//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var shellEnvironment: ShellEnvironment
    @EnvironmentObject private var companionEnvironment: CompanionEnvironment
    @ObservedObject var shellViewModel: ShellViewModel
    @State private var projectCreationError: String?
    @State private var showsCompanionSheet = false
    @State private var showsModelsSheet = false
    @State private var showsMCPToolsSheet = false
    private let projectCreationService: ProjectCreationService

    init(shellViewModel: ShellViewModel, projectCreationService: ProjectCreationService) {
        self.shellViewModel = shellViewModel
        self.projectCreationService = projectCreationService
    }

    var body: some View {
        let companionStatusStore = companionEnvironment.companionStatusStore

        NavigationSplitView {
            ShellSidebarView(
                shellViewModel: shellViewModel,
                isAuthenticated: authViewModel.isAuthenticated,
                onCreateProject: createProjectWithFolderBrowser,
                onOpenProject: openProjectWithFolderBrowser,
                onCheckForUpdates: {
                    try shellEnvironment.appUpdateManager.checkForUpdates()
                },
                companionStatusLabel: companionStatusStore.statusLabel,
                onManageModels: { showsModelsSheet = true },
                onManageCompanion: { showsCompanionSheet = true },
                onManageMCPTools: { showsMCPToolsSheet = true },
                onSignOut: authViewModel.signOut
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 350)
        } detail: {
            ShellDetailPaneView(
                shellViewModel: shellViewModel,
                shellEnvironment: shellEnvironment,
                isAuthenticated: authViewModel.isAuthenticated
            )
            .navigationTitle(navigationHeaderState.title)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ShellOpenProjectMenuButton(shellViewModel: shellViewModel)
            }
        }
        .onChange(of: shellViewModel.selectedItem) { _, newValue in
            shellViewModel.didSelectSidebarItem(newValue)
        }
        .onReceive(shellEnvironment.chatEventsStore.chatTitleDidUpdate) { event in
            shellViewModel.updateChatTitle(chatID: event.chatID, title: event.title)
        }
        .sheet(isPresented: $showsCompanionSheet) {
            CompanionManagementSheet(
                isPresented: $showsCompanionSheet,
                companionStatusStore: companionStatusStore
            )
            .frame(minWidth: 680, minHeight: 480)
        }
        .sheet(isPresented: $showsModelsSheet) {
            ModelsManagementSheet(
                isPresented: $showsModelsSheet,
                modelSelectionStore: shellEnvironment.modelSelectionStore,
                modelRepository: shellEnvironment.modelRepository
            )
                .frame(minWidth: 980, minHeight: 640)
        }
        .sheet(isPresented: $showsMCPToolsSheet) {
            MCPToolsManagementSheet(
                isPresented: $showsMCPToolsSheet,
                mcpToolsStore: shellEnvironment.mcpToolsStore
            )
            .frame(minWidth: 980, minHeight: 640)
        }
        .safeAreaInset(edge: .top) {
            if let warningMessage = activeWarningMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)

                    Text(warningMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button("Dismiss") {
                        dismissActiveWarning()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var activeWarningMessage: String? {
        if let workspaceLoadError = shellViewModel.workspaceLoadError,
           !workspaceLoadError.isEmpty {
            return workspaceLoadError
        }
        if let projectCreationError,
           !projectCreationError.isEmpty {
            return projectCreationError
        }
        if let chatCreationError = shellViewModel.chatCreationError,
           !chatCreationError.isEmpty {
            return chatCreationError
        }
        if let chatDeletionError = shellViewModel.chatDeletionError,
           !chatDeletionError.isEmpty {
            return chatDeletionError
        }
        if let projectDeletionError = shellViewModel.projectDeletionError,
           !projectDeletionError.isEmpty {
            return projectDeletionError
        }

        return nil
    }

    private func dismissActiveWarning() {
        if shellViewModel.workspaceLoadError != nil {
            shellViewModel.clearWorkspaceLoadError()
            return
        }
        if projectCreationError != nil {
            projectCreationError = nil
            return
        }
        if shellViewModel.chatCreationError != nil {
            shellViewModel.clearChatCreationError()
            return
        }
        if shellViewModel.chatDeletionError != nil {
            shellViewModel.clearChatDeletionError()
            return
        }
        if shellViewModel.projectDeletionError != nil {
            shellViewModel.clearProjectDeletionError()
        }
    }

    private var navigationHeaderState: ShellNavigationHeaderState {
        ShellNavigationHeaderState(shellViewModel: shellViewModel)
    }

    private func createProjectWithFolderBrowser() {
        do {
            guard let created = try projectCreationService.createProjectInteractively() else {
                return
            }

            try shellViewModel.addProject(name: created.name, localPath: created.localPath)
        } catch {
            let fallbackMessage = "Could not create project right now."
            projectCreationError = UserFacingErrorMapper.message(error, fallback: fallbackMessage)
        }
    }

    private func openProjectWithFolderBrowser() {
        do {
            guard let opened = try projectCreationService.openProjectInteractively() else {
                return
            }

            try shellViewModel.addProject(name: opened.name, localPath: opened.localPath)
        } catch {
            let fallbackMessage = "Could not open project right now."
            projectCreationError = UserFacingErrorMapper.message(error, fallback: fallbackMessage)
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ContentView(
        shellViewModel: environment.shellEnvironment.shellViewModel,
        projectCreationService: environment.shellEnvironment.projectCreationService
    )
        .environmentObject(environment)
        .environmentObject(environment.authEnvironment.authViewModel)
        .environmentObject(environment.shellEnvironment)
        .environmentObject(environment.companionEnvironment)
}
