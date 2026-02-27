import Foundation

@MainActor
final class CommitMessageAssistantService {
    private let modelSelectionStore: ModelSelectionStore
    private let fetchModelCatalogUseCase: FetchModelCatalogUseCase
    private let sendPromptUseCase: SendPromptUseCase
    private var retryAfter: Date?

    init(
        modelSelectionStore: ModelSelectionStore,
        modelRepository: ModelListingRepository,
        promptRepository: PromptStreamingRepository
    ) {
        self.modelSelectionStore = modelSelectionStore
        self.fetchModelCatalogUseCase = FetchModelCatalogUseCase(repository: modelRepository)
        self.sendPromptUseCase = SendPromptUseCase(repository: promptRepository)
    }

    func generateMessageIfAvailable(changes: [GitFileChange], projectPath: String) async -> String? {
        guard shouldAttemptGeneration else {
            return nil
        }

        do {
            let model = await resolvePreferredModel()
            let prompt = buildCommitMessagePrompt(changes: changes)
            var generatedText = ""

            for try await event in sendPromptUseCase.execute(
                prompt: prompt,
                chatID: UUID(),
                model: model,
                projectPath: projectPath,
                allowedTools: nil
            ) {
                if case .textDelta(let chunk) = event {
                    generatedText += chunk
                }
            }

            let normalized = generatedText
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let firstLine = normalized
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !firstLine.isEmpty else {
                retryAfter = Date().addingTimeInterval(60)
                return nil
            }

            retryAfter = nil
            return firstLine
        } catch {
            retryAfter = Date().addingTimeInterval(60)
            return nil
        }
    }

    private var shouldAttemptGeneration: Bool {
        guard let retryAfter else {
            return true
        }

        return Date() >= retryAfter
    }

    private func resolvePreferredModel() async -> String? {
        let models: [String]
        do {
            models = try await fetchModelCatalogUseCase.execute().map(\.id)
        } catch {
            return nil
        }

        guard !models.isEmpty else { return nil }

        let preferredVisible = Set(modelSelectionStore.selectedModelIDs())
        if preferredVisible.isEmpty {
            return models.first
        }

        let filtered = models.filter { preferredVisible.contains($0) }
        return (filtered.isEmpty ? models : filtered).first
    }

    private func buildCommitMessagePrompt(changes: [GitFileChange]) -> String {
        let summarizedChanges = changes.prefix(20).map { change in
            "- [\(change.state.rawValue)] \(change.path) (+\(change.addedLines)/-\(change.deletedLines))"
        }.joined(separator: "\n")

        return """
        Generate a concise Git commit message for these changes.

        CRITICAL OUTPUT RULES:
        - Respond with ONLY the commit message subject line.
        - Do NOT include any explanation, prefix, suffix, markdown, code fences, or quotes.
        - Do NOT say things like "Here is" or "Let me".
        - Maximum 72 characters.
        - One line only.

        Valid example output:
        Update git panel commit message generation

        Changes:
        \(summarizedChanges)
        """
    }
}
