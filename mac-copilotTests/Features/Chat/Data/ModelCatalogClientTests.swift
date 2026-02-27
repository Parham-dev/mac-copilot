import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct ModelCatalogClientTests {
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

        let models = try await client.fetchModelCatalog()
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

        let wrappedModels = try await wrappedClient.fetchModelCatalog()
        let directModels = try await directClient.fetchModelCatalog()

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

        let models = try await client.fetchModelCatalog()

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

        await #expect {
            try await client.fetchModelCatalog()
        } throws: { error in
            guard case CopilotModelCatalogError.server(let statusCode, _) = error else { return false }
            return statusCode == 500
        }
    }

    // MARK: - HTTP Payload Contract tests

    @Test func fetchUsesModelsGetRouteContract() async throws {
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
            delayScheduler: NoOpDelayScheduler()
        )

        let models = try await client.fetchModelCatalog()
        let request = try #require(transport.lastRequest)

        #expect(models.map(\.id) == ["gpt-5"])
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/models")
        #expect(request.timeoutInterval == 8)
    }
}

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    makeHTTPResponse(statusCode: statusCode)
}
