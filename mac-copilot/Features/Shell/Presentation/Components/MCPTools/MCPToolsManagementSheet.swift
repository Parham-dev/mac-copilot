import SwiftUI

struct MCPToolsManagementSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: MCPToolsManagementViewModel

    init(isPresented: Binding<Bool>, mcpToolsStore: MCPToolsStore) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: MCPToolsManagementViewModel(store: mcpToolsStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MCP Tools")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Enable or disable agent tools used by MCP workflows.")
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
                listPane
                    .frame(minWidth: 380, maxWidth: 460)

                Divider()

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                Text("Enabled: \(viewModel.enabledToolIDs.count) of \(viewModel.tools.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Enable All") {
                    viewModel.enableAll()
                }
                Button("Disable All") {
                    viewModel.disableAll()
                }
                Button("Cancel") {
                    isPresented = false
                }
                Button("Save") {
                    viewModel.save()
                    isPresented = false
                }
                .disabled(viewModel.enabledToolIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .task {
            viewModel.loadTools()
        }
    }

    private var listPane: some View {
        List(viewModel.tools, id: \.id, selection: $viewModel.focusedToolID) { tool in
            HStack(spacing: 10) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.enabledToolIDs.contains(tool.id) },
                        set: { viewModel.setTool(tool.id, isEnabled: $0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .fontWeight(.medium)
                    Text(tool.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(tool.group)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let tool = viewModel.focusedTool {
            VStack(alignment: .leading, spacing: 12) {
                Text(tool.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(tool.id)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                detailsRow("Group", value: tool.group)
                detailsRow("Description", value: tool.summary)
                detailsRow("Status", value: viewModel.enabledToolIDs.contains(tool.id) ? "Enabled" : "Disabled")

                Spacer()
            }
            .padding(20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select a tool")
                    .font(.headline)
                Text("Pick an MCP tool on the left to inspect and configure it.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func detailsRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }
}
