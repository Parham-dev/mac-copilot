//
//  ContentView.swift
//  mac-copilot
//
//  Created by Parham on 25/02/2026.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject var shellViewModel: ShellViewModel
    @State private var projectCreationError: String?
    @State private var showsModelsSheet = false
    private let projectCreationService: ProjectCreationService

    init(shellViewModel: ShellViewModel, projectCreationService: ProjectCreationService = ProjectCreationService()) {
        self.shellViewModel = shellViewModel
        self.projectCreationService = projectCreationService
    }

    var body: some View {
        NavigationSplitView {
            ShellSidebarView(
                shellViewModel: shellViewModel,
                isAuthenticated: authViewModel.isAuthenticated,
                onCreateProject: createProjectWithFolderBrowser,
                onManageModels: { showsModelsSheet = true },
                onSignOut: authViewModel.signOut
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
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
            ShellDetailPaneView(
                shellViewModel: shellViewModel,
                appEnvironment: appEnvironment,
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
        .sheet(isPresented: $showsModelsSheet) {
            ModelsManagementSheet(isPresented: $showsModelsSheet)
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
}

private struct ModelsManagementSheet: View {
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    @StateObject private var viewModel = ModelsManagementViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Models")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Choose which Copilot models appear in the chat model menu.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HStack(spacing: 0) {
                modelsListPane
                    .frame(minWidth: 360, maxWidth: 420)

                Divider()

                detailsPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                Text("Selected: \(viewModel.selectedModelIDs.count) of \(viewModel.models.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select All") {
                    viewModel.selectAll()
                }
                Button("Clear") {
                    viewModel.clearSelection()
                }
                Button("Cancel") {
                    isPresented = false
                }
                Button("Save") {
                    viewModel.saveSelection()
                    isPresented = false
                }
                .disabled(viewModel.selectedModelIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .task {
            await viewModel.loadModels()
        }
    }

    private var modelsListPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                ProgressView("Loading models…")
                    .padding(16)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                List(viewModel.models, id: \.id, selection: $viewModel.focusedModelID) { model in
                    HStack(spacing: 10) {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.selectedModelIDs.contains(model.id) },
                                set: { isSelected in
                                    viewModel.setModel(model.id, isSelected: isSelected)
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        if let billingMultiplier = model.billingMultiplier {
                            modelTag(String(format: "x%.2f", billingMultiplier))
                        }

                        if model.supportsVision {
                            modelTag("Vision")
                        }
                        if model.supportsReasoningEffort {
                            modelTag("Reasoning")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.focusedModelID = model.id
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private var detailsPane: some View {
        if let model = viewModel.focusedModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(model.id)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    detailsRow("Context Window", value: formatInteger(model.maxContextWindowTokens))
                    detailsRow("Max Prompt Tokens", value: formatInteger(model.maxPromptTokens))
                    detailsRow("Vision", value: model.supportsVision ? "Supported" : "Not supported")
                    detailsRow("Reasoning Effort", value: model.supportsReasoningEffort ? "Supported" : "Not supported")
                    detailsRow("Policy", value: model.policyState?.capitalized ?? "Unknown")
                    detailsRow("Billing Multiplier", value: formatMultiplier(model.billingMultiplier))

                    if needsEnableAction(model) {
                        Button("Enable in GitHub Copilot") {
                            openEnableURL(for: model)
                        }
                        Text("This app can read model policy from SDK, but enabling is currently managed in GitHub Copilot settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !model.supportedReasoningEfforts.isEmpty {
                        detailsRow("Supported Efforts", value: model.supportedReasoningEfforts.joined(separator: ", "))
                    }

                    if let defaultEffort = model.defaultReasoningEffort, !defaultEffort.isEmpty {
                        detailsRow("Default Effort", value: defaultEffort)
                    }
                }
                .padding(20)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select a model")
                    .font(.headline)
                Text("Choose a model on the left to inspect available stats from Copilot SDK.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func detailsRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }

    private func modelTag(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }

    private func formatInteger(_ value: Int?) -> String {
        guard let value, value > 0 else { return "Unknown" }
        return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func formatMultiplier(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.2fx", value)
    }

    private func needsEnableAction(_ model: CopilotModelCatalogItem) -> Bool {
        guard let state = model.policyState?.lowercased() else { return false }
        return state != "enabled"
    }

    private func openEnableURL(for model: CopilotModelCatalogItem) {
        if let terms = model.policyTerms,
           let termsURL = URL(string: terms),
           let scheme = termsURL.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            openURL(termsURL)
            return
        }

        if let defaultURL = URL(string: "https://github.com/settings/copilot") {
            openURL(defaultURL)
        }
    }
}

@MainActor
private final class ModelsManagementViewModel: ObservableObject {
    @Published private(set) var models: [CopilotModelCatalogItem] = []
    @Published var selectedModelIDs: Set<String> = []
    @Published var focusedModelID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = CopilotAPIService()

    var focusedModel: CopilotModelCatalogItem? {
        guard let focusedModelID else { return models.first }
        return models.first(where: { $0.id == focusedModelID })
    }

    func loadModels() async {
        guard models.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let fetched = await apiService.fetchModelCatalog()
        models = fetched

        let persisted = Set(ModelSelectionPreferences.selectedModelIDs())
        if persisted.isEmpty {
            selectedModelIDs = Set(fetched.map(\.id))
        } else {
            let visible = Set(fetched.map(\.id).filter { persisted.contains($0) })
            selectedModelIDs = visible.isEmpty ? Set(fetched.map(\.id)) : visible
        }

        if focusedModelID == nil {
            focusedModelID = fetched.first?.id
        }

        isLoading = false
        if fetched.isEmpty {
            errorMessage = "No models are currently available."
        }
    }

    func selectAll() {
        selectedModelIDs = Set(models.map(\.id))
    }

    func clearSelection() {
        selectedModelIDs.removeAll()
    }

    func setModel(_ modelID: String, isSelected: Bool) {
        if isSelected {
            selectedModelIDs.insert(modelID)
        } else {
            selectedModelIDs.remove(modelID)
        }
    }

    func saveSelection() {
        ModelSelectionPreferences.setSelectedModelIDs(Array(selectedModelIDs))
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ContentView(shellViewModel: environment.shellViewModel)
        .environmentObject(environment)
        .environmentObject(environment.authViewModel)
}
