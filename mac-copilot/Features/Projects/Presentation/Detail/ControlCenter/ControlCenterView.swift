import SwiftUI

struct ControlCenterView: View {
    @StateObject private var viewModel: ControlCenterViewModel
    private let chatEventsStore: ChatEventsStore

    private let logsBottomAnchorID = "control-center-logs-bottom-anchor"

    private var logsScrollToken: Int {
        var hasher = Hasher()
        hasher.combine(viewModel.logs.count)
        hasher.combine(viewModel.logs.first ?? "")
        hasher.combine(viewModel.logs.last ?? "")
        hasher.combine(viewModel.logs.reduce(0) { $0 + $1.count })
        return hasher.finalize()
    }

    init(
        project: ProjectRef,
        controlCenterResolver: ProjectControlCenterResolver,
        controlCenterRuntimeManager: ControlCenterRuntimeManager,
        chatEventsStore: ChatEventsStore,
        onFixLogsRequest: ((String) -> Void)?
    ) {
        self.chatEventsStore = chatEventsStore
        _viewModel = StateObject(
            wrappedValue: ControlCenterViewModel(
                project: project,
                resolver: controlCenterResolver,
                runtimeManager: controlCenterRuntimeManager,
                onFixLogsRequest: onFixLogsRequest
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                topSection

                logsSection
                    .frame(height: max(180, geometry.size.height * 0.5))
                    .frame(maxWidth: .infinity)
            }
        }
        .onReceive(chatEventsStore.chatResponseDidFinish) { event in
            let projectPath = event.projectPath
            guard !projectPath.isEmpty else {
                return
            }

            viewModel.handleChatResponseDidFinish(projectPath: projectPath)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Control Center", systemImage: "slider.horizontal.3")

            controlRow
            statusView

            if let urlText = viewModel.activeURLText {
                Text(urlText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !viewModel.shouldShowLogs {
                emptyState
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.startOrStop) {
                if viewModel.runtimeManager.isRunning,
                   viewModel.runtimeManager.activeProjectID == viewModel.project.id {
                    Label("Stop", systemImage: "stop.fill")
                } else {
                    Label("Start", systemImage: "play.fill")
                }
            }
            .disabled(!viewModel.canStartOrStop)

            Button(action: viewModel.refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(!viewModel.canRefresh)

            Button(action: viewModel.openInBrowser) {
                Label("Open", systemImage: "safari")
            }
            .disabled(!viewModel.canOpen)
        }
    }

    private var emptyState: some View {
        Group {
            switch viewModel.resolution {
            case .ready(let launch):
                VStack(alignment: .leading, spacing: 6) {
                    Text(launch.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        adapterBadge(
                            icon: viewModel.adapterIcon,
                            title: launch.adapterName
                        )
                        adapterBadge(
                            icon: "folder",
                            title: viewModel.project.name
                        )
                    }
                }
            case .unavailable(let message):
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logsSection: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                HStack {
                    Button(action: viewModel.copyLogsToClipboard) {
                        Label("Copy Logs", systemImage: "doc.on.doc")
                    }
                    .disabled(!viewModel.canCopyLogs)

                    Spacer()

                    Button(action: viewModel.requestFixWithAI) {
                        Label("Fix with AI", systemImage: "sparkles")
                    }
                    .disabled(!viewModel.canRequestFix)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.logs.isEmpty {
                            Text("Run your project to see logs here.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(logsBottomAnchorID)
                    }
                }
                .onAppear {
                    scrollLogsToBottom(using: proxy, animated: false)
                }
                .onChange(of: logsScrollToken) { _, _ in
                    scheduleLogsScrollToBottom(using: proxy)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var statusView: some View {
        return HStack(spacing: 8) {
            Text(viewModel.statusText)
                .font(.body)
                .foregroundStyle(.secondary)
            if let adapter = viewModel.adapterDisplayName {
                adapterBadge(icon: viewModel.adapterIcon, title: adapter)
            }
        }
    }

    private func adapterBadge(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
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

    private func scrollLogsToBottom(using proxy: ScrollViewProxy, animated: Bool = false) {
        let action = {
            proxy.scrollTo(logsBottomAnchorID, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.2), action)
        } else {
            action()
        }
    }

    private func scheduleLogsScrollToBottom(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            scrollLogsToBottom(using: proxy, animated: false)
        }
    }
}