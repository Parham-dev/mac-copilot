import Foundation
import SwiftData
import Testing
@testable import mac_copilot

@MainActor
struct PersistencePhase4IntegrationTests {
    @Test func swiftData_projectChatMessageRoundtripPreservesOrderingAndMetadata() throws {
        let context = try makeInMemoryContext()
        let projectRepository = SwiftDataProjectRepository(context: context)
        let chatRepository = SwiftDataChatRepository(context: context)

        let project = projectRepository.createProject(name: "Workspace", localPath: "/tmp/workspace")
        let chat = chatRepository.createChat(projectID: project.id, title: "Phase4")

        let createdAtFirst = Date(timeIntervalSince1970: 1_700_000_000)
        let createdAtSecond = createdAtFirst.addingTimeInterval(5)
        let firstMessage = ChatMessage(
            role: .user,
            text: "first",
            metadata: ChatMessage.Metadata(statusChips: ["Queued"], toolExecutions: [
                ChatMessage.ToolExecution(toolName: "list_dir", success: true, details: "ok")
            ]),
            createdAt: createdAtFirst
        )
        let secondMessage = ChatMessage(
            role: .assistant,
            text: "second",
            metadata: ChatMessage.Metadata(statusChips: ["Completed"], toolExecutions: []),
            createdAt: createdAtSecond
        )

        chatRepository.saveMessage(chatID: chat.id, message: secondMessage)
        chatRepository.saveMessage(chatID: chat.id, message: firstMessage)

        var loaded = chatRepository.loadMessages(chatID: chat.id)
        #expect(loaded.count == 2)
        #expect(loaded[0].id == firstMessage.id)
        #expect(loaded[1].id == secondMessage.id)
        #expect(loaded[0].metadata?.statusChips == ["Queued"])
        #expect(loaded[0].metadata?.toolExecutions.first?.toolName == "list_dir")

        let updatedMetadata = ChatMessage.Metadata(statusChips: ["Planning", "Completed"], toolExecutions: [])
        chatRepository.updateMessage(
            chatID: chat.id,
            messageID: secondMessage.id,
            text: "second-updated",
            metadata: updatedMetadata
        )

        loaded = chatRepository.loadMessages(chatID: chat.id)
        let updated = try #require(loaded.first(where: { $0.id == secondMessage.id }))
        #expect(updated.text == "second-updated")
        #expect(updated.metadata?.statusChips == ["Planning", "Completed"])

        let fetchedChats = chatRepository.fetchChats(projectID: project.id)
        #expect(fetchedChats.count == 1)
        #expect(fetchedChats.first?.id == chat.id)

        let fetchedProjects = projectRepository.fetchProjects()
        #expect(fetchedProjects.count == 1)
        #expect(fetchedProjects.first?.id == project.id)
    }

    @Test func swiftData_deleteChatRemovesThreadAndMessages() throws {
        let context = try makeInMemoryContext()
        let projectRepository = SwiftDataProjectRepository(context: context)
        let chatRepository = SwiftDataChatRepository(context: context)

        let project = projectRepository.createProject(name: "Workspace", localPath: "/tmp/workspace")
        let chat = chatRepository.createChat(projectID: project.id, title: "DeleteMe")
        chatRepository.saveMessage(chatID: chat.id, message: ChatMessage(role: .user, text: "hello"))

        #expect(chatRepository.fetchChats(projectID: project.id).count == 1)
        #expect(chatRepository.loadMessages(chatID: chat.id).count == 1)

        chatRepository.deleteChat(chatID: chat.id)

        #expect(chatRepository.fetchChats(projectID: project.id).isEmpty)
        #expect(chatRepository.loadMessages(chatID: chat.id).isEmpty)
    }
}

@MainActor
private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([
        ProjectEntity.self,
        ChatThreadEntity.self,
        ChatMessageEntity.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}