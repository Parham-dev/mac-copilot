import Foundation

extension ChatViewModel {
    func send() async {
        let text = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        await send(prompt: text)
    }

    func send(prompt: String) async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isSending else { return }

        isSending = true
        let hadUserMessageBeforeSend = messages.contains(where: { $0.role == .user })
        let userMessage = sessionCoordinator.appendUserMessage(chatID: chatID, text: text)
        messages.append(userMessage)

        if let updatedTitle = sessionCoordinator.updateChatTitleFromFirstUserMessageIfNeeded(
            chatID: chatID,
            promptText: text,
            hadUserMessageBeforeSend: hadUserMessageBeforeSend
        ) {
            chatTitle = updatedTitle
            NotificationCenter.default.post(
                name: .chatTitleDidUpdate,
                object: nil,
                userInfo: [
                    "chatID": chatID,
                    "title": updatedTitle,
                ]
            )
        }

        let assistantIndex = messages.count
        let assistantMessage = sessionCoordinator.appendAssistantPlaceholder(chatID: chatID)
        messages.append(assistantMessage)
        statusChipsByMessageID[assistantMessage.id] = ["Queued"]
        toolExecutionsByMessageID[assistantMessage.id] = []
        streamingAssistantMessageID = assistantMessage.id
        draftPrompt = ""

        do {
            var hasContent = false
            let enabledMCPTools = mcpToolsStore.enabledToolIDs()
            let allToolIDs = MCPToolsCatalog.all.map(\.id)
            let effectiveAllowedTools: [String]? = {
                if enabledMCPTools.isEmpty {
                    return nil
                }

                let enabledSet = Set(enabledMCPTools)
                let allSet = Set(allToolIDs)
                if enabledSet == allSet {
                    return nil
                }

                return enabledMCPTools
            }()

            for try await event in sendPromptUseCase.execute(
                prompt: text,
                chatID: chatID,
                model: selectedModel.isEmpty ? nil : selectedModel,
                projectPath: projectPath,
                allowedTools: effectiveAllowedTools
            ) {
                switch event {
                case .textDelta(let chunk):
                    hasContent = true
                    if PromptTrace.containsProtocolMarker(in: chunk) {
                        NSLog(
                            "[CopilotForge][PromptTrace] UI received protocol marker chunk (chatID=%@ assistantMessageID=%@ chars=%d preview=%@)",
                            chatID.uuidString,
                            assistantMessage.id.uuidString,
                            chunk.count,
                            String(chunk.prefix(180))
                        )
                    }
                    messages[assistantIndex].text += chunk

                    if PromptTrace.containsProtocolMarker(in: messages[assistantIndex].text) {
                        NSLog(
                            "[CopilotForge][PromptTrace] UI assembled text still contains protocol marker (chatID=%@ assistantMessageID=%@ totalChars=%d)",
                            chatID.uuidString,
                            assistantMessage.id.uuidString,
                            messages[assistantIndex].text.count
                        )
                    }
                case .status(let label):
                    appendStatus(label, for: assistantMessage.id)
                case .toolExecution(let tool):
                    appendToolExecution(tool, for: assistantMessage.id)
                case .completed:
                    appendStatus("Completed", for: assistantMessage.id)
                }
            }

            if !hasContent {
                messages[assistantIndex].text = "No response from Copilot."
            }
        } catch {
            appendStatus("Failed", for: assistantMessage.id)
            messages[assistantIndex].text = "Error: \(error.localizedDescription)"
        }

        sessionCoordinator.persistAssistantContent(
            chatID: chatID,
            messageID: assistantMessage.id,
            text: messages[assistantIndex].text,
            metadata: metadata(for: assistantMessage.id)
        )

        streamingAssistantMessageID = nil
        isSending = false

        NotificationCenter.default.post(
            name: .chatResponseDidFinish,
            object: nil,
            userInfo: ["projectPath": projectPath]
        )
    }
}
