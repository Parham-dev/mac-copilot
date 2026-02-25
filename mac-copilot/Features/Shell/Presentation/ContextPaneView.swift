import SwiftUI
import AppKit
import WebKit

struct ContextPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let project: ProjectRef
    let previewResolver: ProjectPreviewResolver

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Context", selection: $shellViewModel.selectedContextTab) {
                    Text("Preview").tag(ShellViewModel.ContextTab.preview)
                    Text("Git").tag(ShellViewModel.ContextTab.git)
                }
                .pickerStyle(.segmented)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            switch shellViewModel.selectedContextTab {
            case .preview:
                previewPlaceholder
            case .git:
                gitPlaceholder
            }
        }
    }

    private var previewPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Preview", systemImage: "play.rectangle")
                .font(.headline)

            switch previewResolver.resolve(for: project) {
            case .ready(let launch):
                Text(launch.summary)
                    .foregroundStyle(.secondary)

                Text(launch.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("Adapter: \(launch.adapterName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    switch launch.target {
                    case .file(let url), .web(let url):
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(launch.actionTitle, systemImage: "safari")
                }

                PreviewWebView(target: launch.target, projectPath: project.localPath)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

            case .unavailable(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                Text("Add an adapter for this project type (Node/Python server adapters next).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var gitPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Git", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.headline)
            Text("Git status and diffs for \(project.name) will appear here.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PreviewWebView: NSViewRepresentable {
    let target: PreviewLaunchTarget
    let projectPath: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let targetURL: URL
        switch target {
        case .file(let url), .web(let url):
            targetURL = url
        }

        guard context.coordinator.lastLoadedURL != targetURL else { return }
        context.coordinator.lastLoadedURL = targetURL

        switch target {
        case .file(let fileURL):
            let expandedPath = (projectPath as NSString).expandingTildeInPath
            let rootURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
            nsView.loadFileURL(fileURL, allowingReadAccessTo: rootURL)
        case .web(let webURL):
            nsView.load(URLRequest(url: webURL))
        }
    }

    final class Coordinator {
        var lastLoadedURL: URL?
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    let project = environment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
    ContextPaneView(shellViewModel: environment.shellViewModel, project: project, previewResolver: environment.sharedPreviewResolver())
}
