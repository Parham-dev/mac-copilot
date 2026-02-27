import Foundation
import Combine
import Testing
@testable import mac_copilot

// MARK: - Async Helpers

func eventually(timeout: TimeInterval = 1.0, intervalNanoseconds: UInt64 = 20_000_000, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }
    return condition()
}

// MARK: - HTTP Transport Doubles

final class StubHTTPDataTransport: HTTPDataTransporting {
    private var results: [Result<(Data, URLResponse), Error>]
    private(set) var callCount = 0

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
    }

    func appendResults(_ newResults: [Result<(Data, URLResponse), Error>]) {
        results.append(contentsOf: newResults)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        _ = request
        callCount += 1
        guard !results.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let result = results.removeFirst()
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

final class CapturingHTTPDataTransport: HTTPDataTransporting {
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

final class CapturingLineStreamTransport: HTTPLineStreamTransporting {
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

// MARK: - Delay Scheduler Doubles

struct NoOpDelayScheduler: AsyncDelayScheduling {
    func sleep(seconds: TimeInterval) async throws {
        _ = seconds
    }
}

final class RecordingDelayScheduler: AsyncDelayScheduling {
    private(set) var sleeps: [TimeInterval] = []

    func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
    }
}

// MARK: - Model Repository Doubles

final class FakeModelListingRepository: ModelListingRepository {
    private let models: [String]
    private let catalog: [CopilotModelCatalogItem]

    init(models: [String], catalog: [CopilotModelCatalogItem]) {
        self.models = models
        self.catalog = catalog
    }

    func fetchModels() async -> [String] {
        models
    }

    func fetchModelCatalog() async -> [CopilotModelCatalogItem] {
        catalog
    }
}

// MARK: - Prompt Streaming Repository Double

final class FakePromptStreamingRepository: PromptStreamingRepository {
    struct Request {
        let prompt: String
        let chatID: UUID
        let model: String?
        let projectPath: String?
        let allowedTools: [String]?
    }

    private let streamEvents: [PromptStreamEvent]
    private let error: Error?
    private(set) var lastRequest: Request?

    init(streamEvents: [PromptStreamEvent] = [], error: Error? = nil) {
        self.streamEvents = streamEvents
        self.error = error
    }

    func streamPrompt(_ prompt: String, chatID: UUID, model: String?, projectPath: String?, allowedTools: [String]?) -> AsyncThrowingStream<PromptStreamEvent, Error> {
        lastRequest = Request(prompt: prompt, chatID: chatID, model: model, projectPath: projectPath, allowedTools: allowedTools)

        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }

            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

// MARK: - Chat Repository Doubles

@MainActor
final class InMemoryChatRepository: ChatRepository {
    private(set) var chatsByProject: [UUID: [ChatThreadRef]] = [:]
    private(set) var messagesByChat: [UUID: [ChatMessage]] = [:]
    private(set) var updatedMessages: [UUID: (text: String, metadata: ChatMessage.Metadata?)] = [:]
    private(set) var updatedChatTitles: [UUID: String] = [:]

    func fetchChats(projectID: UUID) -> [ChatThreadRef] {
        chatsByProject[projectID] ?? []
    }

    @discardableResult
    func createChat(projectID: UUID, title: String) -> ChatThreadRef {
        let thread = ChatThreadRef(id: UUID(), projectID: projectID, title: title, createdAt: Date())
        chatsByProject[projectID, default: []].append(thread)
        return thread
    }

    func deleteChat(chatID: UUID) {
        for key in chatsByProject.keys {
            chatsByProject[key]?.removeAll(where: { $0.id == chatID })
        }
        messagesByChat.removeValue(forKey: chatID)
    }

    func updateChatTitle(chatID: UUID, title: String) {
        updatedChatTitles[chatID] = title

        for key in chatsByProject.keys {
            guard var chats = chatsByProject[key],
                  let index = chats.firstIndex(where: { $0.id == chatID })
            else {
                continue
            }

            chats[index].title = title
            chatsByProject[key] = chats
            break
        }
    }

    func loadMessages(chatID: UUID) -> [ChatMessage] {
        messagesByChat[chatID] ?? []
    }

    func saveMessage(chatID: UUID, message: ChatMessage) {
        messagesByChat[chatID, default: []].append(message)
    }

    func updateMessage(chatID: UUID, messageID: UUID, text: String, metadata: ChatMessage.Metadata?) {
        updatedMessages[messageID] = (text, metadata)

        guard var messages = messagesByChat[chatID],
              let idx = messages.firstIndex(where: { $0.id == messageID })
        else {
            return
        }

        messages[idx].text = text
        messages[idx].metadata = metadata
        messagesByChat[chatID] = messages
    }
}

@MainActor
final class FixedChatRepository: ChatRepository {
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

// MARK: - Project Repository Double

@MainActor
final class FixedProjectRepository: ProjectRepository {
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

    func deleteProject(projectID: UUID) {
        _ = projectID
    }
}

// MARK: - Preferences Store Doubles

final class InMemoryModelSelectionPreferencesStore: ModelSelectionPreferencesStoring {
    private(set) var storedIDs: [String]

    init(_ ids: [String]) {
        self.storedIDs = ids
    }

    func readSelectedModelIDs() -> [String] {
        storedIDs
    }

    func writeSelectedModelIDs(_ ids: [String]) {
        storedIDs = ids
    }
}

final class InMemoryMCPToolsPreferencesStore: MCPToolsPreferencesStoring {
    private(set) var storedIDs: [String]

    init(_ ids: [String]) {
        self.storedIDs = ids
    }

    func readEnabledMCPToolIDs() -> [String] {
        storedIDs
    }

    func writeEnabledMCPToolIDs(_ ids: [String]) {
        storedIDs = ids
    }
}

// MARK: - Lifecycle Doubles

@MainActor
final class RecordingLifecycleManager: SidecarLifecycleManaging {
    private(set) var starts = 0

    func startIfNeeded() {
        starts += 1
    }

    func restart() {}
    func stop() {}
}

// MARK: - URL Protocol Stub

final class URLProtocolSnapshotStub: URLProtocol {
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

// MARK: - Keychain Token Store Doubles

/// In-memory keychain token store for testing.
/// Stores the token in a plain property — no real Keychain I/O.
final class InMemoryKeychainTokenStore: KeychainTokenStoring {
    private(set) var storedToken: String?
    private(set) var saveCallCount = 0
    private(set) var readCallCount = 0
    private(set) var deleteCallCount = 0

    init(existingToken: String? = nil) {
        self.storedToken = existingToken
    }

    func saveToken(_ token: String) throws {
        saveCallCount += 1
        storedToken = token
    }

    func readToken() -> String? {
        readCallCount += 1
        return storedToken
    }

    func deleteToken() {
        deleteCallCount += 1
        storedToken = nil
    }
}

/// A keychain store that always throws on save — for testing error paths.
final class ThrowingKeychainTokenStore: KeychainTokenStoring {
    let error: Error
    private(set) var storedToken: String?

    init(error: Error = AuthError.server("Keychain save failed")) {
        self.error = error
    }

    func saveToken(_ token: String) throws {
        throw error
    }

    func readToken() -> String? {
        storedToken
    }

    func deleteToken() {
        storedToken = nil
    }
}

// MARK: - HTTP Response Helpers

func makeHTTPResponse(statusCode: Int, url: URL = URL(string: "http://127.0.0.1:7878/models")!) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

func successResult(data: Data, response: URLResponse) -> Result<(Data, URLResponse), Error> {
    .success((data, response))
}

// MARK: - Request Body Helper

func requestBodyData(_ request: URLRequest) -> Data? {
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
