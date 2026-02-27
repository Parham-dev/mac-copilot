import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct CompanionSyncPayloadTests {
    @Test func postsSnapshotPayloadWithProjectsChatsMessages() async {
        URLProtocolSnapshotStub.reset()
        URLProtocol.registerClass(URLProtocolSnapshotStub.self)
        defer {
            URLProtocol.unregisterClass(URLProtocolSnapshotStub.self)
            URLProtocolSnapshotStub.reset()
        }

        URLProtocolSnapshotStub.requestHandler = { request in
            let path = request.url?.path ?? ""
            if path == "/health" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            if path == "/companion/sync/snapshot" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("{\"ok\":true}".utf8))
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let project = ProjectRef(id: UUID(), name: "Demo", localPath: "/tmp/demo")
        let chat = ChatThreadRef(id: UUID(), projectID: project.id, title: "Main Chat", createdAt: Date(timeIntervalSince1970: 1_700_000_100))
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "hello companion",
            createdAt: Date(timeIntervalSince1970: 1_700_000_200)
        )

        let projectRepo = FixedProjectRepository(projects: [project])
        let chatRepo = FixedChatRepository(chatsByProjectID: [project.id: [chat]], messagesByChatID: [chat.id: [message]])
        let lifecycle = RecordingLifecycleManager()

        let service = SidecarCompanionWorkspaceSyncService(
            projectRepository: projectRepo,
            chatRepository: chatRepo,
            sidecarLifecycle: lifecycle,
            baseURL: URL(string: "http://phase4.local")!
        )

        await service.syncWorkspaceSnapshot()

        let postRequest = URLProtocolSnapshotStub.requests.first(where: { $0.url?.path == "/companion/sync/snapshot" })
        let body = postRequest.flatMap(requestBodyData)
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let projects = json?["projects"] as? [[String: Any]]
        let chats = json?["chats"] as? [[String: Any]]
        let messages = json?["messages"] as? [[String: Any]]

        #expect(postRequest?.httpMethod == "POST")
        #expect(projects?.count == 1)
        #expect(chats?.count == 1)
        #expect(messages?.count == 1)
        #expect((projects?.first?["id"] as? String) == project.id.uuidString)
        #expect((chats?.first?["projectId"] as? String) == project.id.uuidString)
        #expect((messages?.first?["chatId"] as? String) == chat.id.uuidString)
    }
}
