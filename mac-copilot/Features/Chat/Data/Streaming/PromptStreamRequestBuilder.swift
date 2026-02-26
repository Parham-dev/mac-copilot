import Foundation

enum PromptStreamRequestBuilder {
    static func makeRequest(
        baseURL: URL,
        prompt: String,
        chatID: UUID,
        model: String?,
        projectPath: String?,
        allowedTools: [String]?
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("prompt"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "prompt": prompt,
            "chatID": chatID.uuidString,
            "projectPath": projectPath ?? "",
        ]

        if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["model"] = model
        }

        if let allowedTools {
            payload["allowedTools"] = allowedTools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}