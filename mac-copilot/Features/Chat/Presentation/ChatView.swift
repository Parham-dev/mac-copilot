import SwiftUI
#if DEBUG
import AppKit
#endif

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var modelSelectionStore: ModelSelectionStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "message")
                    .font(.title3)
                Text(viewModel.chatTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
#if DEBUG
                Button {
                    copyDebugContext()
                } label: {
                    Label("Copy Debug", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
#endif
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            ChatTranscriptView(
                messages: viewModel.messages,
                statusChipsByMessageID: viewModel.statusChipsByMessageID,
                inlineSegmentsByMessageID: viewModel.inlineSegmentsByMessageID,
                streamingAssistantMessageID: viewModel.streamingAssistantMessageID
            )

            Divider()

            if hasWarningBanner {
                VStack(spacing: 0) {
                    if let modelCatalogWarning = viewModel.modelCatalogErrorMessage,
                       !modelCatalogWarning.isEmpty {
                        warningBannerRow(
                            message: modelCatalogWarning,
                            onDismiss: { viewModel.clearModelCatalogErrorMessage() }
                        )
                    }

                    if let persistenceWarning = viewModel.messagePersistenceErrorMessage,
                       !persistenceWarning.isEmpty {
                        warningBannerRow(
                            message: persistenceWarning,
                            onDismiss: { viewModel.clearMessagePersistenceErrorMessage() }
                        )
                    }
                }

                Divider()
            }

            ChatComposerView(
                draftPrompt: $viewModel.draftPrompt,
                selectedModel: $viewModel.selectedModel,
                availableModels: viewModel.availableModels,
                selectedModelInfoLabel: viewModel.selectedModelInfoLabel,
                isSending: viewModel.isSending,
                onSend: { Task { await viewModel.send() } }
            )
        }
        .task(id: viewModel.chatID) {
#if DEBUG
            NSLog("[CopilotForge][ChatView] loadModels task triggered chatID=%@", viewModel.chatID.uuidString)
#endif
            await viewModel.loadModelsIfNeeded()
        }
        .onChange(of: modelSelectionStore.changeToken) { _, _ in
#if DEBUG
            NSLog("[CopilotForge][ChatView] modelSelection changeToken triggered chatID=%@", viewModel.chatID.uuidString)
#endif
            Task {
                await viewModel.loadModelsIfNeeded(forceReload: true)
            }
        }
    }

    private var hasWarningBanner: Bool {
        (viewModel.modelCatalogErrorMessage?.isEmpty == false)
            || (viewModel.messagePersistenceErrorMessage?.isEmpty == false)
    }

    private func warningBannerRow(message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

#if DEBUG
private extension ChatView {
    func copyDebugContext() {
        let enabledTools = viewModel.nativeToolsStore.enabledNativeToolIDs()
        let resolvedTools = enabledTools.isEmpty ? ["<all-tools-enabled>"] : enabledTools

        let payload = [
            "chatID=\(viewModel.chatID.uuidString)",
            "chatTitle=\(viewModel.chatTitle)",
            "projectPath=\(viewModel.projectPath)",
            "selectedModel=\(viewModel.selectedModel)",
            "enabledNativeTools=\(resolvedTools.joined(separator: ","))",
            "streamingAssistantMessageID=\(viewModel.streamingAssistantMessageID?.uuidString ?? "nil")",
            "messageCount=\(viewModel.messages.count)",
            "timestamp=\(ISO8601DateFormatter().string(from: Date()))"
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
    }
}
#endif

#Preview {
    NavigationStack {
        let environment = AppEnvironment.preview()
        let projectsEnv = environment.projectsEnvironment
        let vm = projectsEnv.projectsViewModel
        let project = vm.activeProject ?? ProjectRef(name: "Preview", localPath: "~/CopilotForgeProjects/preview")
        let chat = vm.chats(for: project.id).first ?? ChatThreadRef(projectID: project.id, title: "General")
        ChatView(
            viewModel: projectsEnv.chatViewModel(for: chat, project: project),
            modelSelectionStore: projectsEnv.modelSelectionStore
        )
    }
}
