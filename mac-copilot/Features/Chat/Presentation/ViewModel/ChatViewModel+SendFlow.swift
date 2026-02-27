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
        messagePersistenceErrorMessage = nil
        let hadUserMessageBeforeSend = messages.contains(where: { $0.role == .user })
        let userMessage: ChatMessage
        do {
            userMessage = try sessionCoordinator.appendUserMessage(chatID: chatID, text: text)
        } catch {
            isSending = false
            messagePersistenceErrorMessage = "Could not save your message locally."
            return
        }
        messages.append(userMessage)

        do {
            if let updatedTitle = try sessionCoordinator.updateChatTitleFromFirstUserMessageIfNeeded(
                chatID: chatID,
                promptText: text,
                hadUserMessageBeforeSend: hadUserMessageBeforeSend
            ) {
                chatTitle = updatedTitle
                chatEventsStore.publishChatTitleDidUpdate(chatID: chatID, title: updatedTitle)
            }
        } catch {
            messagePersistenceErrorMessage = "Message was saved, but chat title update failed."
        }

        let assistantIndex = messages.count
        let assistantMessage: ChatMessage
        do {
            assistantMessage = try sessionCoordinator.appendAssistantPlaceholder(chatID: chatID)
        } catch {
            isSending = false
            messagePersistenceErrorMessage = "Could not prepare a local placeholder for the assistant response."
            return
        }
        messages.append(assistantMessage)
        statusChipsByMessageID[assistantMessage.id] = ["Queued"]
        toolExecutionsByMessageID[assistantMessage.id] = []
        inlineSegmentsByMessageID[assistantMessage.id] = []
        streamingAssistantMessageID = assistantMessage.id
        draftPrompt = ""

        do {
            var hasContent = false
            var assembledAssistantText = ""
            var renderedSegments: [AssistantTranscriptSegment] = []
            var flushedAssistantText = ""
            let effectiveAllowedTools = resolveAllowedToolsForCurrentContext()
            let isProjectChat = !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let enabledNativeToolCount = nativeToolsStore.enabledNativeToolIDs().count
            let catalogCount = NativeToolsCatalog.all.count
            let requestedToolCount = effectiveAllowedTools?.count ?? catalogCount
            NSLog(
                "[CopilotForge][Tools] send_context chatID=%@ mode=%@ enabledNativeToolCount=%d catalogCount=%d requestedAllowedToolCount=%d requestedAllowedToolsNil=%@ requestedAllowedToolsSample=%@",
                chatID.uuidString,
                isProjectChat ? "project" : "agent",
                enabledNativeToolCount,
                catalogCount,
                requestedToolCount,
                effectiveAllowedTools == nil ? "true" : "false",
                String((effectiveAllowedTools ?? Array(NativeToolsCatalog.all.map(\.id).prefix(5))).prefix(5).joined(separator: ","))
            )

            func textTailSinceLastFlush() -> String {
                guard !assembledAssistantText.isEmpty else { return "" }
                guard !flushedAssistantText.isEmpty else { return assembledAssistantText }

                if assembledAssistantText.hasPrefix(flushedAssistantText) {
                    return String(assembledAssistantText.dropFirst(flushedAssistantText.count))
                }

                return assembledAssistantText
            }

            func currentRenderedSegments() -> [AssistantTranscriptSegment] {
                var segments = renderedSegments
                let pending = textTailSinceLastFlush()
                if !pending.isEmpty {
                    segments.append(.text(pending))
                }
                return segments
            }

            func updateInlineSegments() {
                inlineSegmentsByMessageID[assistantMessage.id] = currentRenderedSegments()
            }

            func flushTextSegment() {
                let pending = textTailSinceLastFlush()
                guard !pending.isEmpty else { return }
                renderedSegments.append(.text(pending))
                flushedAssistantText = assembledAssistantText
            }

            for try await event in sendPromptUseCase.execute(
                prompt: text,
                chatID: chatID,
                model: selectedModel.isEmpty ? nil : selectedModel,
                projectPath: projectPath,
                allowedTools: effectiveAllowedTools
            ) {
                switch event {
                case .textDelta(let chunk):
                    if PromptTrace.containsProtocolMarker(in: chunk) {
                        NSLog(
                            "[CopilotForge][PromptTrace] UI received protocol marker chunk (chatID=%@ assistantMessageID=%@ chars=%d preview=%@)",
                            chatID.uuidString,
                            assistantMessage.id.uuidString,
                            chunk.count,
                            String(chunk.prefix(180))
                        )
                    }

                    assembledAssistantText = StreamTextAssembler.merge(current: assembledAssistantText, incoming: chunk)
                    messages[assistantIndex].text = assembledAssistantText
                    updateInlineSegments()
                    if !assembledAssistantText.isEmpty {
                        hasContent = true
                    }

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
                    let entry = appendToolExecution(tool, for: assistantMessage.id)
                    flushTextSegment()
                    renderedSegments.append(.tool(entry))
                    updateInlineSegments()
                    if !renderedSegments.isEmpty || !assembledAssistantText.isEmpty {
                        hasContent = true
                    }
                case .completed:
                    appendStatus("Completed", for: assistantMessage.id)
                }
            }

            flushTextSegment()
            inlineSegmentsByMessageID[assistantMessage.id] = renderedSegments

            if !hasContent {
                messages[assistantIndex].text = "No response from Copilot."
                inlineSegmentsByMessageID[assistantMessage.id] = [.text("No response from Copilot.")]
            }
        } catch {
            appendStatus("Failed", for: assistantMessage.id)
            messages[assistantIndex].text = "The response failed to complete. Please try again."
            inlineSegmentsByMessageID[assistantMessage.id] = [.text(messages[assistantIndex].text)]
        }

        do {
            try sessionCoordinator.persistAssistantContent(
                chatID: chatID,
                messageID: assistantMessage.id,
                text: messages[assistantIndex].text,
                metadata: metadata(for: assistantMessage.id)
            )
        } catch {
            messagePersistenceErrorMessage = "Response is shown, but local save failed."
        }

        streamingAssistantMessageID = nil
        isSending = false
        chatEventsStore.publishChatResponseDidFinish(projectPath: projectPath)
    }

    private func resolveAllowedToolsForCurrentContext() -> [String]? {
        let normalizedProjectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let isProjectChat = !normalizedProjectPath.isEmpty

        if isProjectChat {
            let enabledToolIDs = Set(nativeToolsStore.enabledNativeToolIDs())
            let allToolIDs = Set(NativeToolsCatalog.all.map(\.id))

            if enabledToolIDs.isEmpty || enabledToolIDs == allToolIDs {
                return nil
            }

            return Array(enabledToolIDs).sorted()
        }

        return NativeToolsCatalog.defaultAgentToolIDs
    }
}
