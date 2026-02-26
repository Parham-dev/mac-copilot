import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct CopilotModelCatalogClientPhase2Tests {
    @Test func decodesWrappedObjectPayload() async throws {
        let data = try CopilotModelCatalogPayloadFixture.wrappedObjectsData()
        let transport = StubHTTPDataTransport(results: [successResult(data: data, response: makeResponse(statusCode: 200))])
        var sidecarEnsures = 0

        let client = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: { sidecarEnsures += 1 },
            transport: transport,
            delayScheduler: NoOpDelayScheduler()
        )

        let models = await client.fetchModelCatalog()
        let byID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        let gpt5 = try #require(byID["gpt-5"])
        let claude = try #require(byID["claude-opus-4"])

        #expect(sidecarEnsures == 1)
        #expect(models.count == 2)
        #expect(gpt5.supportsVision)
        #expect(claude.maxPromptTokens == 64000)
    }

    @Test func decodesStringPayloadShapes() async throws {
        let wrappedStringData = try CopilotModelCatalogPayloadFixture.wrappedStringListData()
        let directStringData = try CopilotModelCatalogPayloadFixture.directStringListData()

        let wrappedClient = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            transport: StubHTTPDataTransport(results: [successResult(data: wrappedStringData, response: makeResponse(statusCode: 200))]),
            delayScheduler: NoOpDelayScheduler()
        )

        let directClient = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            transport: StubHTTPDataTransport(results: [successResult(data: directStringData, response: makeResponse(statusCode: 200))]),
            delayScheduler: NoOpDelayScheduler()
        )

        let wrappedModels = await wrappedClient.fetchModelCatalog()
        let directModels = await directClient.fetchModelCatalog()

        let wrappedIDs = wrappedModels.map { $0.id }
        let directIDs = directModels.map { $0.id }

        #expect(wrappedIDs == ["claude-opus-4", "gpt-5"])
        #expect(directIDs == ["claude-opus-4", "gpt-5"])
    }

    @Test func retriesRecoverableConnectionErrorOnce() async throws {
        let payload = try CopilotModelCatalogPayloadFixture.wrappedStringListData()
        let transport = StubHTTPDataTransport(
            results: [
                .failure(URLError(.cannotConnectToHost)),
                successResult(data: payload, response: makeResponse(statusCode: 200))
            ]
        )

        var sidecarEnsures = 0
        let delay = RecordingDelayScheduler()

        let client = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: { sidecarEnsures += 1 },
            transport: transport,
            delayScheduler: delay
        )

        let models = await client.fetchModelCatalog()

        #expect(models.count == 2)
        #expect(transport.callCount == 2)
        #expect(sidecarEnsures == 2)
        #expect(delay.sleeps == [0.45])
    }

    @Test func returnsEmptyOnHttpFailure() async {
        let response = makeResponse(statusCode: 500)
        let client = CopilotModelCatalogClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            transport: StubHTTPDataTransport(results: [successResult(data: Data("{}".utf8), response: response)]),
            delayScheduler: NoOpDelayScheduler()
        )

        let models = await client.fetchModelCatalog()
        #expect(models.isEmpty)
    }
}

private func successResult(data: Data, response: URLResponse) -> Result<(Data, URLResponse), Error> {
    .success((data, response))
}

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "http://127.0.0.1:7878/models")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private final class StubHTTPDataTransport: HTTPDataTransporting {
    private var results: [Result<(Data, URLResponse), Error>]
    private(set) var callCount = 0

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
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

private struct NoOpDelayScheduler: AsyncDelayScheduling {
    func sleep(seconds: TimeInterval) async throws {
        _ = seconds
    }
}

private final class RecordingDelayScheduler: AsyncDelayScheduling {
    private(set) var sleeps: [TimeInterval] = []

    func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
    }
}

