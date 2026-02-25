import SwiftUI

struct PreviewContextView: View {
    let project: ProjectRef
    let previewResolver: ProjectPreviewResolver
    @ObservedObject var previewRuntimeManager: PreviewRuntimeManager
    let onFixLogsRequest: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Preview", systemImage: "play.rectangle")
                .font(.headline)

            controlRow
            statusView

            if let url = previewRuntimeManager.activeURL,
               previewRuntimeManager.activeProjectID == project.id {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if previewRuntimeManager.logs.isEmpty {
                emptyState
            } else {
                logsSection
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            Button {
                if previewRuntimeManager.isRunning,
                   previewRuntimeManager.activeProjectID == project.id {
                    previewRuntimeManager.stop()
                } else {
                    previewRuntimeManager.start(project: project, autoOpen: true)
                }
            } label: {
                if previewRuntimeManager.isRunning,
                   previewRuntimeManager.activeProjectID == project.id {
                    Label("Stop", systemImage: "stop.fill")
                } else {
                    Label("Start", systemImage: "play.fill")
                }
            }
            .disabled(previewRuntimeManager.isBusy)

            Button {
                previewRuntimeManager.refresh(project: project)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(previewRuntimeManager.isBusy || previewRuntimeManager.activeProjectID != project.id)

            Button {
                previewRuntimeManager.openInBrowser()
            } label: {
                Label("Open", systemImage: "safari")
            }
            .disabled(previewRuntimeManager.activeURL == nil)
        }
    }

    private var emptyState: some View {
        Group {
            switch previewResolver.resolve(for: project) {
            case .ready(let launch):
                VStack(alignment: .leading, spacing: 6) {
                    Text(launch.summary)
                        .foregroundStyle(.secondary)
                    Text("Detected adapter: \(launch.adapterName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .unavailable(let message):
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    onFixLogsRequest?(fixPrompt)
                } label: {
                    Label("Fix with AI", systemImage: "sparkles")
                }
                .disabled(onFixLogsRequest == nil || previewRuntimeManager.isBusy)

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(previewRuntimeManager.logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var statusView: some View {
        let text: String
        switch previewRuntimeManager.state {
        case .idle:
            text = "Idle"
        case .installing:
            text = "Installing dependencies…"
        case .starting:
            text = "Starting server…"
        case .running:
            text = "Running"
        case .failed(let message):
            text = "Failed: \(message)"
        }

        return HStack(spacing: 8) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let adapter = previewRuntimeManager.adapterName {
                Text("• \(adapter)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fixPrompt: String {
        let stateText: String
        switch previewRuntimeManager.state {
        case .idle:
            stateText = "idle"
        case .installing:
            stateText = "installing"
        case .starting:
            stateText = "starting"
        case .running:
            stateText = "running"
        case .failed(let message):
            stateText = "failed: \(message)"
        }

        let adapter = previewRuntimeManager.adapterName ?? "unknown"
        let logs = previewRuntimeManager.logs.suffix(120).joined(separator: "\n")

        return """
        We tried to start project \(project.name) at path \(project.localPath), but preview runtime has issues.

        Adapter: \(adapter)
        Runtime state: \(stateText)

        Runtime logs:
        \(logs)

        Please analyze the failure, make the required code/config fixes in this project, and then tell me to press Start again.
        """
    }
}