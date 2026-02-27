import Foundation
import Testing
@testable import mac_copilot

@MainActor
struct PromptStreamPayloadTests {
    @Test func postPayloadIncludesExpectedFields() async throws {
        let transport = CapturingLineStreamTransport()
        let chatID = UUID()
        let client = CopilotPromptStreamClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            lineStreamTransport: transport,
            delayScheduler: NoOpDelayScheduler()
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

    @Test func omitsBlankModelAndNilToolsFromPayload() async throws {
        let transport = CapturingLineStreamTransport()
        let client = CopilotPromptStreamClient(
            baseURL: URL(string: "http://127.0.0.1:7878")!,
            ensureSidecarRunning: {},
            lineStreamTransport: transport,
            delayScheduler: NoOpDelayScheduler()
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
}
