import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct ChatViewModelTests {
    @Test func loadModels_appliesPreferredVisibilityAndSelectionFallback() async {
        let modelRepo = FakeModelListingRepository(
            models: ["gpt-5", "claude-opus-4", "gemini-3-pro"],
            catalog: [
                CopilotModelCatalogItem(id: "gpt-5", name: "GPT-5", maxContextWindowTokens: nil, maxPromptTokens: nil, supportsVision: true, supportsReasoningEffort: true, policyState: nil, policyTerms: nil, billingMultiplier: nil, supportedReasoningEfforts: [], defaultReasoningEffort: nil),
                CopilotModelCatalogItem(id: "claude-opus-4", name: "Claude", maxContextWindowTokens: nil, maxPromptTokens: nil, supportsVision: false, supportsReasoningEffort: true, policyState: nil, policyTerms: nil, billingMultiplier: nil, supportedReasoningEfforts: [], defaultReasoningEffort: nil)
            ]
        )
        let modelStore = ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore(["claude-opus-4"]))

        let viewModel = makeViewModel(modelRepo: modelRepo, modelSelectionStore: modelStore)
        viewModel.selectedModel = "missing-model"

        await viewModel.loadModelsIfNeeded(forceReload: true)

        #expect(viewModel.availableModels == ["claude-opus-4"])
        #expect(viewModel.selectedModel == "claude-opus-4")
        #expect(viewModel.modelCatalogByID["gpt-5"] != nil)
    }

    @Test func loadModels_clearsSelectionWhenFetchReturnsEmpty() async {
        let modelRepo = FakeModelListingRepository(models: [], catalog: [])
        let viewModel = makeViewModel(modelRepo: modelRepo)
        viewModel.selectedModel = "gpt-5"

        await viewModel.loadModelsIfNeeded(forceReload: true)

        #expect(viewModel.availableModels.isEmpty)
        #expect(viewModel.selectedModel.isEmpty)
    }

    @Test func send_successfulStreamPersistsAssistantMetadataAndToolEvents() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .status("Planning"),
                .toolExecution(PromptToolExecutionEvent(toolName: "read_file", success: true, details: "opened")),
                .textDelta("Hello"),
                .textDelta(" world"),
                .completed
            ]
        )

        let chatRepo = InMemoryChatRepository()
        let viewModel = makeViewModel(promptRepo: promptRepo, chatRepo: chatRepo)
        viewModel.draftPrompt = "  build feature  "

        await viewModel.send()

        #expect(!viewModel.isSending)
        #expect(viewModel.streamingAssistantMessageID == nil)
        #expect(viewModel.draftPrompt.isEmpty)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].text == "build feature")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].text == "Hello world")

        let assistantID = viewModel.messages[1].id
        let chips = viewModel.statusChipsByMessageID[assistantID] ?? []
        #expect(chips == ["Queued", "Planning", "Completed"])

        let tools = viewModel.toolExecutionsByMessageID[assistantID] ?? []
        #expect(tools.count == 1)
        #expect(tools.first?.toolName == "read_file")
        #expect(tools.first?.success == true)

        #expect(promptRepo.lastRequest?.prompt == "build feature")
        #expect(promptRepo.lastRequest?.allowedTools == nil)

        let inlineSegments = viewModel.inlineSegmentsByMessageID[assistantID] ?? []
        #expect(
            inlineSegments.map(segmentMarker) == [
                "tool:read_file:success:opened::",
                "text:Hello world"
            ]
        )

        let persisted = try? #require(chatRepo.updatedMessages[assistantID])
        #expect(persisted?.text == "Hello world")
        #expect(persisted?.metadata?.statusChips == ["Queued", "Planning", "Completed"])
        #expect((persisted?.metadata?.toolExecutions.count ?? 0) == 1)
        #expect(
            persisted?.metadata?.transcriptSegments.map(segmentMarker)
                == [
                    "tool:read_file:success:opened::",
                    "text:Hello world"
                ]
        )
    }

    @Test func send_failureMarksFailedAndWritesErrorMessage() async throws {
        let promptRepo = FakePromptStreamingRepository(error: PromptStreamError(message: "Boom"))
        let chatRepo = InMemoryChatRepository()
        let viewModel = makeViewModel(promptRepo: promptRepo, chatRepo: chatRepo)

        await viewModel.send(prompt: "test")

        #expect(!viewModel.isSending)
        #expect(viewModel.messages.count == 2)
        let assistant = viewModel.messages[1]
        #expect(assistant.text.contains("response failed"))
        let chips = viewModel.statusChipsByMessageID[assistant.id] ?? []
        #expect(chips == ["Queued", "Failed"])

        let persisted = try #require(chatRepo.updatedMessages[assistant.id])
        #expect(persisted.text.contains("response failed") == true)
    }

    @Test func send_usesAllowedToolsSubsetWhenNotAllEnabled() async {
        let promptRepo = FakePromptStreamingRepository(streamEvents: [.textDelta("ok")])
        let toolStore = MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore(["read_file", "list_dir"]))
        let viewModel = makeViewModel(promptRepo: promptRepo, mcpToolsStore: toolStore)

        await viewModel.send(prompt: "test")

        #expect(promptRepo.lastRequest?.allowedTools == ["list_dir", "read_file"])
    }

    @Test func send_firstPromptUpdatesChatTitleUsingTruncatedText() async throws {
        let promptRepo = FakePromptStreamingRepository(streamEvents: [.textDelta("ok")])
        let chatRepo = InMemoryChatRepository()
        let viewModel = makeViewModel(promptRepo: promptRepo, chatRepo: chatRepo)
        let longPrompt = "Build a robust sidebar synchronization strategy for dynamic chat title updates after first prompt"

        await viewModel.send(prompt: longPrompt)

        let updatedTitle = try #require(chatRepo.updatedChatTitles[viewModel.chatID])
        #expect(updatedTitle != nil)
        #expect(updatedTitle.count <= 48)
        #expect(updatedTitle.hasSuffix("...") == true)
        #expect(updatedTitle.hasPrefix("Build a robust sidebar synchronization") == true)
        #expect(viewModel.chatTitle == updatedTitle)
    }

    @Test func send_streamAssemblerHandlesCumulativeChunksWithoutDuplication() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("Let me check the actual current working directory:"),
                .textDelta("Let me check the actual current working directory:Now let me read the files:"),
                .textDelta("Let me check the actual current working directory:Now let me read the files:This is a basic Node.js web server project")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        let assistantText = viewModel.messages.last?.text ?? ""
        #expect(assistantText == "Let me check the actual current working directory: Now let me read the files: This is a basic Node.js web server project")
    }

    @Test func send_streamAssemblerHandlesCumulativeWhitespaceVariantsWithoutDuplication() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("Let me check the current directory:"),
                .textDelta("Let me check the current directory:\nNow let me view the files with proper paths:"),
                .textDelta("Now let me view the files with proper paths:")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "Let me check the current directory:\nNow let me view the files with proper paths:")
    }

    @Test func send_streamAssemblerHandlesOverlappingDeltaChunks() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("Hello wor"),
                .textDelta("world")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "Hello world")
    }

    @Test func send_streamAssemblerDoesNotSplitWordsAcrossChunks() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("some"),
                .textDelta("f words and charact"),
                .textDelta("eristics")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "somef words and characteristics")
    }

    @Test func send_streamAssemblerPreservesMarkdownBoldMarkersAcrossChunks() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("• *"),
                .textDelta("*Frontend:** An index.html with a Hello World page")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "• **Frontend:** An index.html with a Hello World page")
    }

    @Test func send_streamAssemblerAvoidsSingleCharacterOverlapLetterDrop() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("This project has:\n- **N"),
                .textDelta("Name**: `basic-node-app`")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "This project has:\n- **Name**: `basic-node-app`")
    }

    @Test func send_streamAssemblerFormatsOrderedListBoundaries() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("1."),
                .textDelta("A homepage"),
                .textDelta("2. CSS styling"),
                .textDelta("3"),
                .textDelta("An HTML file")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(viewModel.messages.last?.text == "1. A homepage\n2. CSS styling3 An HTML file")
    }

    @Test func send_inlineToolCallAppearsBetweenTextSegmentsInOrder() async {
        let promptRepo = FakePromptStreamingRepository(
            streamEvents: [
                .textDelta("First segment. "),
                .toolExecution(
                    PromptToolExecutionEvent(
                        toolName: "read_file",
                        success: true,
                        details: "opened",
                        input: "{\"path\":\"/tmp\"}",
                        output: "[\"app.js\",\"package.json\"]"
                    )
                ),
                .textDelta("Second segment.")
            ]
        )

        let viewModel = makeViewModel(promptRepo: promptRepo)
        await viewModel.send(prompt: "inspect")

        #expect(
            viewModel.inlineSegmentsByMessageID[viewModel.messages.last?.id ?? UUID()]?.map(segmentMarker)
                == [
                    "text:First segment. ",
                    "tool:read_file:success:opened:{\"path\":\"/tmp\"}:[\"app.js\",\"package.json\"]",
                    "text:Second segment."
                ]
        )
        #expect(viewModel.messages.last?.text == "First segment. Second segment.")
    }
}

// MARK: - Helpers

private func segmentMarker(_ segment: AssistantTranscriptSegment) -> String {
    switch segment {
    case .text(let text):
        return "text:\(text)"
    case .tool(let tool):
        let state = tool.success ? "success" : "failed"
        return "tool:\(tool.toolName):\(state):\(tool.details ?? ""):\(tool.input ?? ""):\(tool.output ?? "")"
    }
}

@MainActor
private func makeViewModel(
    promptRepo: FakePromptStreamingRepository = FakePromptStreamingRepository(streamEvents: [.textDelta("ok")]),
    modelRepo: FakeModelListingRepository = FakeModelListingRepository(models: ["gpt-5"], catalog: []),
    modelSelectionStore: ModelSelectionStore? = nil,
    mcpToolsStore: MCPToolsStore? = nil,
    chatRepo: InMemoryChatRepository? = nil
) -> ChatViewModel {
    let resolvedModelSelectionStore = modelSelectionStore ?? ModelSelectionStore(preferencesStore: InMemoryModelSelectionPreferencesStore([]))
    let resolvedMCPToolsStore = mcpToolsStore ?? MCPToolsStore(preferencesStore: InMemoryMCPToolsPreferencesStore([]))
    let resolvedChatRepo = chatRepo ?? InMemoryChatRepository()

    return ChatViewModel(
        chatID: UUID(),
        chatTitle: "Test Chat",
        projectPath: "/tmp/project",
        sendPromptUseCase: SendPromptUseCase(repository: promptRepo),
        fetchModelCatalogUseCase: FetchModelCatalogUseCase(repository: modelRepo),
        modelSelectionStore: resolvedModelSelectionStore,
        mcpToolsStore: resolvedMCPToolsStore,
        chatRepository: resolvedChatRepo,
        chatEventsStore: ChatEventsStore()
    )
}
