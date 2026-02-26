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
                onManageModels: { showsModelsSheet = true },
                onManageMCPTools: { showsMCPToolsSheet = true },
                onSignOut: authViewModel.signOut
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            .navigationTitle("CopilotForge")
            .toolbar {
                ToolbarItem {
                    Button {
                        showsCompanionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(companionStatusStore.statusColor)
                                .frame(width: 6, height: 6)
                            Image(systemName: "iphone")
                            Text(companionStatusStore.statusLabel)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Mobile companion status")
                }

                ToolbarItem {
                    Button(action: shellViewModel.createChatInActiveProject) {
                        Label("New Chat", systemImage: "plus")
                    }
                    .disabled(!authViewModel.isAuthenticated)
                }
            }
        } detail: {
            ShellDetailPaneView(
                shellViewModel: shellViewModel,
                shellEnvironment: shellEnvironment,
                isAuthenticated: authViewModel.isAuthenticated
            )
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
