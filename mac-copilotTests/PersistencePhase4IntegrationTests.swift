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

        let project = try projectRepository.createProject(name: "Workspace", localPath: "/tmp/workspace")
        let chat = try chatRepository.createChat(projectID: project.id, title: "Phase4")

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

        try chatRepository.saveMessage(chatID: chat.id, message: secondMessage)
        try chatRepository.saveMessage(chatID: chat.id, message: firstMessage)

        var loaded = try chatRepository.loadMessages(chatID: chat.id)
        #expect(loaded.count == 2)
        #expect(loaded[0].id == firstMessage.id)
        #expect(loaded[1].id == secondMessage.id)
        #expect(loaded[0].metadata?.statusChips == ["Queued"])
        #expect(loaded[0].metadata?.toolExecutions.first?.toolName == "list_dir")

        let updatedMetadata = ChatMessage.Metadata(statusChips: ["Planning", "Completed"], toolExecutions: [])
        try chatRepository.updateMessage(
            chatID: chat.id,
            messageID: secondMessage.id,
            text: "second-updated",
            metadata: updatedMetadata
        )

        loaded = try chatRepository.loadMessages(chatID: chat.id)
        let updated = try #require(loaded.first(where: { $0.id == secondMessage.id }))
        #expect(updated.text == "second-updated")
        #expect(updated.metadata?.statusChips == ["Planning", "Completed"])

        let fetchedChats = try chatRepository.fetchChats(projectID: project.id)
        #expect(fetchedChats.count == 1)
        #expect(fetchedChats.first?.id == chat.id)

        let fetchedProjects = try projectRepository.fetchProjects()
        #expect(fetchedProjects.count == 1)
        #expect(fetchedProjects.first?.id == project.id)
    }

    @Test func swiftData_deleteChatRemovesThreadAndMessages() throws {
        let context = try makeInMemoryContext()
        let projectRepository = SwiftDataProjectRepository(context: context)
        let chatRepository = SwiftDataChatRepository(context: context)

        let project = try projectRepository.createProject(name: "Workspace", localPath: "/tmp/workspace")
        let chat = try chatRepository.createChat(projectID: project.id, title: "DeleteMe")
        try chatRepository.saveMessage(chatID: chat.id, message: ChatMessage(role: .user, text: "hello"))

        #expect(try chatRepository.fetchChats(projectID: project.id).count == 1)
        #expect(try chatRepository.loadMessages(chatID: chat.id).count == 1)

        try chatRepository.deleteChat(chatID: chat.id)

        #expect(try chatRepository.fetchChats(projectID: project.id).isEmpty)
        #expect(try chatRepository.loadMessages(chatID: chat.id).isEmpty)
    }

    @Test func swiftData_loadMessages_decodesLegacyMetadataWithoutToolExecutionID() throws {
        let context = try makeInMemoryContext()
        let projectRepository = SwiftDataProjectRepository(context: context)
        let chatRepository = SwiftDataChatRepository(context: context)

        let project = try projectRepository.createProject(name: "Workspace", localPath: "/tmp/workspace")
        let chat = try chatRepository.createChat(projectID: project.id, title: "Legacy")

        let legacyMetadata = "{\"statusChips\":[\"Queued\"],\"toolExecutions\":[{\"toolName\":\"read_file\",\"success\":true,\"details\":\"ok\"}]}"
        let legacyMessage = ChatMessageEntity(
            id: UUID(),
            chatID: chat.id,
            roleRaw: ChatMessage.Role.assistant.rawValue,
            text: "legacy",
            metadataJSON: legacyMetadata,
            createdAt: Date(timeIntervalSince1970: 1_700_000_500),
            chat: nil
        )

        context.insert(legacyMessage)
        try context.save()

        let loaded = try chatRepository.loadMessages(chatID: chat.id)

        #expect(loaded.count == 1)
        #expect(loaded[0].metadata?.statusChips == ["Queued"])
        #expect(loaded[0].metadata?.toolExecutions.count == 1)
        #expect(loaded[0].metadata?.toolExecutions.first?.toolName == "read_file")
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