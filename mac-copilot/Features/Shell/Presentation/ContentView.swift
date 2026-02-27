//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var shellViewModel: ShellViewModel
    @EnvironmentObject private var featureRegistry: AppFeatureRegistry
    @EnvironmentObject private var projectsEnvironment: ProjectsEnvironment
    @EnvironmentObject private var companionEnvironment: CompanionEnvironment
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var showsCompanionSheet = false
    @State private var showsModelsSheet = false
    @State private var showsMCPToolsSheet = false
    @State private var showsProfileSheet = false
    @State private var updateStatusMessage: String?
    @State private var updateStatusTask: Task<Void, Never>?

    var body: some View {
        let companionStatusStore = companionEnvironment.companionStatusStore

        NavigationSplitView {
            ShellSidebarView(
                shellViewModel: shellViewModel,
                isAuthenticated: authViewModel.isAuthenticated,
                companionStatusLabel: companionStatusStore.statusLabel,
                isUpdateAvailable: true,
                onCheckForUpdates: {
                    showTransientUpdateStatus("Checking for updates...")
                    do {
                        try projectsEnvironment.appUpdateManager.checkForUpdates()
                    } catch {
                        updateStatusTask?.cancel()
                        updateStatusMessage = UserFacingErrorMapper.message(
                            error,
                            fallback: "Could not check for updates right now."
                        )
                    }
                },
                onOpenProfile: { showsProfileSheet = true },
                onManageModels: { showsModelsSheet = true },
                onManageCompanion: { showsCompanionSheet = true },
                onManageMCPTools: { showsMCPToolsSheet = true },
                onSignOut: authViewModel.signOut,
                // Shell → VM: called exactly once per user List tap.
                // Syncs the feature VM from the shell selection without relying
                // on $selectionByFeature which double-fires on Dictionary mutation.
                onListSelectionChange: { featureID, newSelection in
                    projectsEnvironment.handleShellListSelectionChange(
                        featureID: featureID,
                        newSelection: newSelection
                    )
                }
            )
            .environmentObject(featureRegistry)
            .environmentObject(authViewModel)
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            ShellDetailView(shellViewModel: shellViewModel)
                .environmentObject(featureRegistry)
                .environmentObject(authViewModel)
                .navigationTitle(navigationTitle)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ShellOpenProjectMenuButton(projectsViewModel: projectsEnvironment.projectsViewModel)
            }
        }
        // VM → Shell: keep shellViewModel in sync whenever ProjectsViewModel
        // changes its selected item. This covers bootstrap (initial selection from
        // persistence), createChat, deleteChat, deleteProject, and addProject —
        // all paths that mutate ProjectsViewModel.selectedItem without going through
        // the List selection binding. Without this, shellViewModel.selectionByFeature
        // ["projects"] stays nil and ShellDetailView always renders "Select a chat".
        .onReceive(projectsEnvironment.projectsViewModel.$selectedItem) { newItem in
            projectsEnvironment.syncSelectionToShell(newItem, shellViewModel: shellViewModel)
        }
        .onReceive(projectsEnvironment.chatEventsStore.chatTitleDidUpdate) { event in
            projectsEnvironment.handleChatTitleDidUpdate(chatID: event.chatID, title: event.title)
        }
        .sheet(isPresented: $showsProfileSheet) {
            ProfileView(
                isPresented: $showsProfileSheet,
                viewModel: appEnvironment.profileEnvironment.profileViewModel
            )
            .environmentObject(authViewModel)
            .frame(minWidth: 680, minHeight: 520)
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
                modelSelectionStore: projectsEnvironment.modelSelectionStore,
                modelRepository: projectsEnvironment.modelRepository
            )
            .frame(minWidth: 980, minHeight: 640)
        }
        .sheet(isPresented: $showsMCPToolsSheet) {
            MCPToolsManagementSheet(
                isPresented: $showsMCPToolsSheet,
                mcpToolsStore: projectsEnvironment.mcpToolsStore
            )
            .frame(minWidth: 980, minHeight: 640)
        }
        .safeAreaInset(edge: .top) {
            if let warningMessage = activeWarningMessage {
                warningBanner(message: warningMessage)
            }
        }
    }

    // MARK: - Navigation title

    private var navigationTitle: String {
        guard let activeFeatureID = shellViewModel.activeFeatureID,
              let feature = featureRegistry.features.first(where: { $0.id == activeFeatureID })
        else { return "" }
        return feature.navigationTitle(shellViewModel.selection(for: activeFeatureID))
    }

    // MARK: - Warning banner

    private var activeWarningMessage: String? {
        if let projectWarning = projectsEnvironment.activeWarningMessage { return projectWarning }
        if let updateStatusMessage, !updateStatusMessage.isEmpty { return updateStatusMessage }
        return nil
    }

    @ViewBuilder
    private func warningBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(message)
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

    private func dismissActiveWarning() {
        if projectsEnvironment.dismissActiveWarning() { return }
        if updateStatusMessage != nil {
            updateStatusTask?.cancel()
            updateStatusMessage = nil
        }
    }

    private func showTransientUpdateStatus(_ message: String) {
        updateStatusTask?.cancel()
        updateStatusMessage = message
        updateStatusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            updateStatusMessage = nil
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ContentView()
        .environmentObject(environment)
        .environmentObject(environment.authEnvironment.authViewModel)
        .environmentObject(environment.shellViewModel)
        .environmentObject(environment.featureRegistry)
        .environmentObject(environment.projectsEnvironment)
        .environmentObject(environment.companionEnvironment)
}
