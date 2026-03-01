import SwiftUI

struct AgentsDetailView: View {
    @EnvironmentObject private var agentsEnvironment: AgentsEnvironment
    let selection: AnyHashable?
    @StateObject private var viewModel = AgentsDetailViewModel()

    var body: some View {
        if let item = selection as? AgentsFeatureModule.SidebarItem {
            switch item {
            case .agent(let agentID):
                if let definition = agentsEnvironment.definition(id: agentID) {
                    agentDetail(definition: definition)
                        .onAppear {
                            viewModel.activateAgentIfNeeded(definition, environment: agentsEnvironment)
                            Task { await agentsEnvironment.loadModels() }
                        }
                        .onChange(of: agentID) { _, _ in
                            viewModel.activateAgentIfNeeded(definition, environment: agentsEnvironment)
                        }
                } else {
                    ContentUnavailableView("Agent not found", systemImage: "exclamationmark.triangle")
                }
            }
        } else {
            ContentUnavailableView("Select an agent", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    @ViewBuilder
    private func agentDetail(definition: AgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(definition.description)
                .foregroundStyle(.secondary)

            switch viewModel.selectedTab {
            case .run:
                runTab(definition: definition)
            case .history:
                historyTab(definition: definition)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $viewModel.selectedTab) {
                    ForEach(AgentsDetailViewModel.Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
    }

    @ViewBuilder
    private func runTab(definition: AgentDefinition) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inputs")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Model", selection: $agentsEnvironment.selectedModelID) {
                            ForEach(agentsEnvironment.availableModels, id: \.self) { modelID in
                                Text(modelID).tag(modelID)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isRunning || agentsEnvironment.isLoadingModels)

                        if agentsEnvironment.isLoadingModels {
                            Text("Loading models…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(definition.inputSchema.fields, id: \.id) { field in
                        fieldInput(field)
                    }
                }

                if let modelLoadErrorMessage = agentsEnvironment.modelLoadErrorMessage,
                   !modelLoadErrorMessage.isEmpty {
                    Text(modelLoadErrorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button(viewModel.primaryRunButtonTitle) {
                        if viewModel.canOpenLatestResult {
                            viewModel.selectedTab = .history
                        } else {
                            Task {
                                await viewModel.runAgent(definition, environment: agentsEnvironment)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning)

                    if let latestRun = viewModel.latestRun {
                        HStack(spacing: 6) {
                            Text("Latest run")
                                .foregroundStyle(.secondary)
                            AgentStatusBadgeView(status: latestRun.status)
                        }
                    }

                }

                if viewModel.isRunning,
                   let runActivity = viewModel.runActivity,
                   !runActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("AI is working: \(runActivity)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func historyTab(definition: AgentDefinition) -> some View {
        let runs = viewModel.runsForCurrentAgent(definition.id, environment: agentsEnvironment)

        if runs.isEmpty {
            ContentUnavailableView(
                "No History Yet",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                description: Text("Run the agent to populate history and review outputs here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            HStack(spacing: 0) {
                List(selection: $viewModel.selectedRunID) {
                    ForEach(runs, id: \.id) { run in
                        AgentRunHistoryRowView(
                            run: run,
                            format: viewModel.displayOutputFormat(for: run)
                        )
                        .tag(run.id)
                    }
                }
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    if let selected = viewModel.selectedRun(from: runs) {
                        resultSection(for: selected)
                    } else {
                        ContentUnavailableView(
                            "No Run Selected",
                            systemImage: "clock",
                            description: Text("Pick a run from the left to inspect output and export.")
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onAppear {
                viewModel.ensureSelectedRun(from: runs)
            }
            .onChange(of: runs.map(\.id)) { _, _ in
                viewModel.ensureSelectedRun(from: runs)
            }
        }
    }

    @ViewBuilder
    private func resultSection(for run: AgentRun) -> some View {
        AgentResultPanelView(
            run: run,
            format: viewModel.displayOutputFormat(for: run),
            resultText: viewModel.preferredResultText(for: run),
            resultFont: viewModel.resultFont(for: run),
            onCopy: { value in
                viewModel.copyToClipboard(value)
            },
            onDownload: {
                viewModel.downloadRunContent(run)
            }
        )
    }

    @ViewBuilder
    private func fieldInput(_ field: AgentInputField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let suffix = field.required ? " *" : ""
            Text("\(field.label)\(suffix)")
                .font(.subheadline)
                .fontWeight(.medium)

            switch field.type {
            case .url, .text:
                TextField(field.id, text: binding(for: field.id))
                    .textFieldStyle(.roundedBorder)

            case .select:
                Picker(field.label, selection: binding(for: field.id)) {
                    Text("Select...").tag("")
                    ForEach(field.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { viewModel.formValues[key] ?? "" },
            set: { viewModel.formValues[key] = $0 }
        )
    }
}
