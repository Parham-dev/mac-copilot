import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct PayloadContractsPhase4Tests {
    @Test func modelCatalog_fetchUsesModelsGetRouteContract() async {
        let transport = CapturingHTTPDataTransport(
            result: .success((
                Data("[\"gpt-5\"]".utf8),
                HTTPURLResponse(url: URL(string: "http://127.0.0.1:7878/models")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            ))
        )

        let client = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            transport: transport,
            delayScheduler: NoOpDelaySchedulerPhase4()
        )

        let models = await client.fetchModelCatalog()
        let request = try? #require(transport.lastRequest)

        #expect(models.map(\.id) == ["gpt-5"])
        #expect(request?.httpMethod == "GET")
        #expect(request?.url?.path == "/models")
        #expect(request?.timeoutInterval == 8)
    }

    @Test func promptStream_postPayloadIncludesExpectedFields() async throws {
        let transport = CapturingLineStreamTransport()
        let chatID = UUID()
        let client = CopilotPromptStreamClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            lineStreamTransport: transport,
            delayScheduler: NoOpDelaySchedulerPhase4()
        )

        let stream = client.streamPrompt(
            "hello",
            chatID: chatID,
            model: "gpt-5",
            projectPath: "/tmp/workspace",
            allowedTools: ["read_file", "list_dir"]
        )
        for try await _ in stream {}

        let request = try #require(transport.lastRequest)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/prompt")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect((json["prompt"] as? String) == "hello")
        #expect((json["chatID"] as? String) == chatID.uuidString)
        #expect((json["projectPath"] as? String) == "/tmp/workspace")
        #expect((json["model"] as? String) == "gpt-5")
        #expect((json["allowedTools"] as? [String]) == ["read_file", "list_dir"])
    }

    @Test func promptStream_omitsBlankModelAndNilToolsFromPayload() async throws {
        let transport = CapturingLineStreamTransport()
        let client = CopilotPromptStreamClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            lineStreamTransport: transport,
            delayScheduler: NoOpDelaySchedulerPhase4()
        )

        let stream = client.streamPrompt(
            "hello",
            chatID: UUID(),
            model: "   ",
            projectPath: nil,
            allowedTools: nil
        )
        for try await _ in stream {}

        let request = try #require(transport.lastRequest)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(json["model"] == nil)
        #expect(json["allowedTools"] == nil)
        #expect((json["projectPath"] as? String) == "")
    }

    @Test func companionSync_postsSnapshotPayloadWithProjectsChatsMessages() async {
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

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var data = Data()
    while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)
        if bytesRead <= 0 {
            break
        }
        data.append(buffer, count: bytesRead)
    }

    return data.isEmpty ? nil : data
}

private final class CapturingHTTPDataTransport: HTTPDataTransporting {
    private let result: Result<(Data, URLResponse), Error>
    private(set) var lastRequest: URLRequest?

    init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

private final class CapturingLineStreamTransport: HTTPLineStreamTransporting {
    private(set) var lastRequest: URLRequest?

    func openLineStream(for request: URLRequest) async throws -> HTTPLineStreamResponse {
        lastRequest = request

        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("data: [DONE]")
            continuation.finish()
        }

        return HTTPLineStreamResponse(
            lines: stream,
            response: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}

private struct NoOpDelaySchedulerPhase4: AsyncDelayScheduling {
    func sleep(seconds: TimeInterval) async throws {
        _ = seconds
    }
}

@MainActor
private final class RecordingLifecycleManager: SidecarLifecycleManaging {
    private(set) var starts = 0

    func startIfNeeded() {
        starts += 1
    }

    func restart() {}
    func stop() {}
}

@MainActor
private final class FixedProjectRepository: ProjectRepository {
    private let projects: [ProjectRef]

    init(projects: [ProjectRef]) {
        self.projects = projects
    }

    func fetchProjects() -> [ProjectRef] {
        projects
    }

    @discardableResult
    func createProject(name: String, localPath: String) -> ProjectRef {
        ProjectRef(name: name, localPath: localPath)
    }
}

@MainActor
private final class FixedChatRepository: ChatRepository {
    private let chatsByProjectID: [UUID: [ChatThreadRef]]
    private let messagesByChatID: [UUID: [ChatMessage]]

    init(chatsByProjectID: [UUID: [ChatThreadRef]], messagesByChatID: [UUID: [ChatMessage]]) {
        self.chatsByProjectID = chatsByProjectID
        self.messagesByChatID = messagesByChatID
    }

    func fetchChats(projectID: UUID) -> [ChatThreadRef] {
        chatsByProjectID[projectID] ?? []
    }

    @discardableResult
    func createChat(projectID: UUID, title: String) -> ChatThreadRef {
        ChatThreadRef(projectID: projectID, title: title)
    }

    func deleteChat(chatID: UUID) {
        _ = chatID
    }

    func updateChatTitle(chatID: UUID, title: String) {
        _ = chatID
        _ = title
    }

    func loadMessages(chatID: UUID) -> [ChatMessage] {
        messagesByChatID[chatID] ?? []
    }

    func saveMessage(chatID: UUID, message: ChatMessage) {
        _ = chatID
        _ = message
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) {
        _ = chatID
        _ = messageID
        _ = text
        _ = metadata
    }
}

private final class URLProtocolSnapshotStub: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "phase4.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Self.requests.append(request)
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
        requests = []
    }
}