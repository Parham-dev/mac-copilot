import SwiftUI

struct ContextPaneView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    let project: ProjectRef

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
            Text("Live preview for \(project.name) will appear here.")
                .foregroundStyle(.secondary)
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

#Preview {
    let environment = AppEnvironment.preview()
    let project = environment.shellViewModel.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
    ContextPaneView(shellViewModel: environment.shellViewModel, project: project)
}
