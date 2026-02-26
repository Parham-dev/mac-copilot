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
        .onReceive(NotificationCenter.default.publisher(for: .chatTitleDidUpdate)) { notification in
            guard let chatID = notification.userInfo?["chatID"] as? UUID,
                  let title = notification.userInfo?["title"] as? String
            else {
                return
            }

            shellViewModel.updateChatTitle(chatID: chatID, title: title)
        }
        .alert("Could not create project", isPresented: projectCreationAlertBinding) {
            Button("OK", role: .cancel) {
                projectCreationError = nil
            }
        } message: {
            Text(projectCreationError ?? "Unknown error")
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

    private var navigationHeaderState: ShellNavigationHeaderState {
        ShellNavigationHeaderState(shellViewModel: shellViewModel)
    }

    private func createProjectWithFolderBrowser() {
        do {
            guard let created = try projectCreationService.createProjectInteractively() else {
                return
            }

            shellViewModel.addProject(name: created.name, localPath: created.localPath)
        } catch {
            projectCreationError = error.localizedDescription
        }
    }

    private func openProjectWithFolderBrowser() {
        do {
            guard let opened = try projectCreationService.openProjectInteractively() else {
                return
            }

            shellViewModel.addProject(name: opened.name, localPath: opened.localPath)
        } catch {
            projectCreationError = error.localizedDescription
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
