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
        let requirementsFields = definition.inputSchema.fields.filter(isRequirementsField)
        let advancedFields = advancedFields(for: definition)
        let advancedFieldIDs = Set(advancedFields.map(\ .id))
        let selectFields = definition.inputSchema.fields.filter { $0.type == .select && !advancedFieldIDs.contains($0.id) }
        let primaryFields = definition.inputSchema.fields.filter {
            $0.type != .select && !isRequirementsField($0) && !advancedFieldIDs.contains($0.id)
        }

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AgentRunModelSectionView(
                        selectedModelID: $agentsEnvironment.selectedModelID,
                        availableModels: agentsEnvironment.availableModels,
                        isLoadingModels: agentsEnvironment.isLoadingModels,
                        isDisabled: viewModel.isRunning
                    )

                    if !primaryFields.isEmpty {
                        AgentRunPrimaryFieldsSectionView(
                            fields: primaryFields,
                            bindingForFieldID: binding(for:),
                            hasUploadedFiles: viewModel.hasUploadedFiles,
                            uploadedFiles: viewModel.uploadedFileItems,
                            onUploadFiles: {
                                viewModel.addUploadedFiles()
                            },
                            onRemoveUploadedFile: { fileID in
                                viewModel.removeUploadedFile(id: fileID)
                            }
                        )
                    }

                    if !selectFields.isEmpty {
                        AgentRunPreferencesSectionView(
                            fields: selectFields,
                            selectedValue: { field in
                                viewModel.selectedValue(for: field)
                            },
                            onSelectOption: { field, option in
                                viewModel.selectOption(option, for: field)
                            },
                            isOtherSelected: { field in
                                viewModel.isOtherSelected(for: field)
                            },
                            customValueBinding: { field in
                                customBinding(for: field)
                            }
                        )
                    }

                    if !advancedFields.isEmpty {
                        AgentRunAdvancedSectionView(
                            isExpanded: $viewModel.isAdvancedExpanded,
                            fields: advancedFields,
                            selectedValue: { field in
                                viewModel.selectedValue(for: field)
                            },
                            onSelectOption: { field, option in
                                viewModel.selectOption(option, for: field)
                            },
                            isOtherSelected: { field in
                                viewModel.isOtherSelected(for: field)
                            },
                            customValueBinding: { field in
                                customBinding(for: field)
                            },
                            extraContext: binding(for: viewModel.advancedExtraContextFieldID)
                        )
                    }

                    if !requirementsFields.isEmpty {
                        AgentRunRequirementsSectionView(
                            fields: requirementsFields,
                            bindingForFieldID: binding(for:)
                        )
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()

            AgentRunFooterBarView(
                modelErrorMessage: agentsEnvironment.modelLoadErrorMessage,
                errorMessage: viewModel.errorMessage,
                isRunning: viewModel.isRunning,
                runButtonTitle: viewModel.primaryRunButtonTitle,
                latestRun: viewModel.latestRun,
                runActivity: viewModel.runActivity,
                onRun: {
                    Task {
                        await viewModel.runAgent(definition, environment: agentsEnvironment)
                    }
                }
            )
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
                            format: viewModel.displayOutputFormat(for: run),
                            onDelete: {
                                viewModel.requestDeleteRun(run)
                            }
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
            .confirmationDialog(
                "Delete run?",
                isPresented: Binding(
                    get: { viewModel.pendingDeleteRun != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.cancelDeleteRun()
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteRun(definition: definition, environment: agentsEnvironment)
                }

                Button("Cancel", role: .cancel) {
                    viewModel.cancelDeleteRun()
                }
            } message: {
                Text("This run and its output will be permanently removed.")
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

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { viewModel.formValues[key] ?? "" },
            set: { viewModel.formValues[key] = $0 }
        )
    }

    private func customBinding(for field: AgentInputField) -> Binding<String> {
        Binding(
            get: { viewModel.customValue(for: field) },
            set: { viewModel.setCustomValue($0, for: field) }
        )
    }

    private func isRequirementsField(_ field: AgentInputField) -> Bool {
        let fieldID = field.id.lowercased()
        return fieldID.contains("requirement") || fieldID.contains("constraint")
    }

    private func advancedFields(for definition: AgentDefinition) -> [AgentInputField] {
        guard definition.id == "content-summariser" else {
            return []
        }

        var fields: [AgentInputField] = []

        if let audienceField = definition.inputSchema.fields.first(where: { $0.id == "audience" }) {
            fields.append(audienceField)
        }

        fields.append(
            AgentInputField(
                id: viewModel.advancedCitationModeFieldID,
                label: "Citation Mode",
                type: .select,
                required: false,
                options: ["auto", "inline links", "references"]
            )
        )

        return fields
    }
}
