import SwiftUI

struct AgentsDetailView: View {
    @EnvironmentObject private var agentsEnvironment: AgentsEnvironment
    let selection: AnyHashable?

    @State private var formValues: [String: String] = [:]
    @State private var activeAgentID: String?
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var latestRun: AgentRun?

    var body: some View {
        if let item = selection as? AgentsFeatureModule.SidebarItem {
            switch item {
            case .agent(let agentID):
                if let definition = agentsEnvironment.definition(id: agentID) {
                    agentDetail(definition: definition)
                        .onAppear {
                            activateAgentIfNeeded(definition)
                            Task { await agentsEnvironment.loadModels() }
                        }
                        .onChange(of: agentID) { _, _ in
                            activateAgentIfNeeded(definition)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(definition.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(definition.description)
                    .foregroundStyle(.secondary)

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
                        .disabled(isRunning || agentsEnvironment.isLoadingModels)

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

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button(isRunning ? "Running..." : "Run") {
                        runAgent(definition)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)

                    if let latestRun {
                        Text("Latest run: \(latestRun.status.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                }

                if let latestRun {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Result")
                            .font(.headline)

                        if let finalOutput = latestRun.finalOutput,
                           !finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ScrollView {
                                Text(finalOutput)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(minHeight: 140, maxHeight: 260)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if let streamedOutput = latestRun.streamedOutput,
                                  !streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ScrollView {
                                Text(streamedOutput)
                                    .font(.callout)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(minHeight: 140, maxHeight: 260)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Text("No output body was produced for this run.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        if !latestRun.diagnostics.warnings.isEmpty {
                            Text("Warnings: \(latestRun.diagnostics.warnings.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if !recentRuns(for: definition.id).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Runs")
                            .font(.headline)

                        ForEach(recentRuns(for: definition.id), id: \.id) { run in
                            HStack {
                                Text(run.startedAt, style: .time)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(run.status.rawValue)
                            }
                            .font(.callout)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            get: { formValues[key] ?? "" },
            set: { formValues[key] = $0 }
        )
    }

    private func activateAgentIfNeeded(_ definition: AgentDefinition) {
        guard activeAgentID != definition.id else { return }

        activeAgentID = definition.id
        errorMessage = nil
        isRunning = false
        latestRun = nil

        var initialValues: [String: String] = [:]
        for field in definition.inputSchema.fields {
            if field.type == .select {
                initialValues[field.id] = field.options.first ?? ""
            } else {
                initialValues[field.id] = ""
            }
        }
        formValues = initialValues

        agentsEnvironment.loadRuns(agentID: definition.id)
    }

    private func runAgent(_ definition: AgentDefinition) {
        errorMessage = nil

        let selectedModel = agentsEnvironment.selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            errorMessage = "Please select a model before running."
            return
        }

        for field in definition.inputSchema.fields where field.required {
            let value = (formValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                errorMessage = "Please fill required field: \(field.label)"
                return
            }
        }

        isRunning = true
        Task { @MainActor in
            do {
                let run = try await agentsEnvironment.executeRun(
                    definition: definition,
                    projectID: nil,
                    inputPayload: formValues,
                    model: selectedModel,
                    projectPath: nil
                )

                latestRun = run

                if run.status == .failed {
                    errorMessage = "Run completed but output schema validation failed."
                }
            } catch {
                errorMessage = "Execution failed. Please retry."
            }

            isRunning = false
        }
    }

    private func recentRuns(for agentID: String) -> [AgentRun] {
        Array(agentsEnvironment.runs.filter { $0.agentID == agentID }.prefix(5))
    }
}
