import Foundation

enum PromptStreamRequestBuilder {
    static func makeRequest(
        baseURL: URL,
        prompt: String,
        chatID: UUID,
        model: String?,
        projectPath: String?,
        allowedTools: [String]?,
        executionContext: PromptExecutionContext?
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

        if let executionContext {
            payload["executionContext"] = [
                "agentID": executionContext.agentID,
                "feature": executionContext.feature,
                "policyProfile": executionContext.policyProfile,
                "skillNames": executionContext.skillNames,
                "requireSkills": executionContext.requireSkills,
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}