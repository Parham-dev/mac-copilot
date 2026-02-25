import SwiftUI

struct ControlCenterView: View {
    let project: ProjectRef
    let controlCenterResolver: ProjectControlCenterResolver
    @ObservedObject var controlCenterRuntimeManager: ControlCenterRuntimeManager
    let onFixLogsRequest: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Control Center", systemImage: "slider.horizontal.3")

            controlRow
            statusView

            if let url = controlCenterRuntimeManager.activeURL,
               controlCenterRuntimeManager.activeProjectID == project.id {
                Text(url.absoluteString)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if controlCenterRuntimeManager.logs.isEmpty {
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
                if controlCenterRuntimeManager.isRunning,
                   controlCenterRuntimeManager.activeProjectID == project.id {
                    controlCenterRuntimeManager.stop()
                } else {
                    controlCenterRuntimeManager.start(project: project, autoOpen: true)
                }
            } label: {
                if controlCenterRuntimeManager.isRunning,
                   controlCenterRuntimeManager.activeProjectID == project.id {
                    Label("Stop", systemImage: "stop.fill")
                } else {
                    Label("Start", systemImage: "play.fill")
                }
            }
            .disabled(controlCenterRuntimeManager.isBusy)

            Button {
                controlCenterRuntimeManager.refresh(project: project)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(controlCenterRuntimeManager.isBusy || controlCenterRuntimeManager.activeProjectID != project.id)

            Button {
                controlCenterRuntimeManager.openInBrowser()
            } label: {
                Label("Open", systemImage: "safari")
            }
            .disabled(controlCenterRuntimeManager.activeURL == nil)
        }
    }

    private var emptyState: some View {
        Group {
            switch controlCenterResolver.resolve(for: project) {
            case .ready(let launch):
                VStack(alignment: .leading, spacing: 6) {
                    Text(launch.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Detected adapter: \(launch.adapterName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            case .unavailable(let message):
                Text(message)
                    .font(.body)
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
                .disabled(onFixLogsRequest == nil || controlCenterRuntimeManager.isBusy)

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(controlCenterRuntimeManager.logs.enumerated()), id: \.offset) { _, line in
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
        switch controlCenterRuntimeManager.state {
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
                .font(.body)
                .foregroundStyle(.secondary)
            if let adapter = controlCenterRuntimeManager.adapterName {
                Text("• \(adapter)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func panelTitle(_ title: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

    private var fixPrompt: String {
        let stateText: String
        switch controlCenterRuntimeManager.state {
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

        let adapter = controlCenterRuntimeManager.adapterName ?? "unknown"
        let logs = controlCenterRuntimeManager.logs.suffix(120).joined(separator: "\n")

        return """
        We tried to start project \(project.name) at path \(project.localPath), but control center runtime has issues.

        Adapter: \(adapter)
        Runtime state: \(stateText)

        Runtime logs:
        \(logs)

        Please analyze the failure, make the required code/config fixes in this project, and then tell me to press Start again.
        """
    }
}