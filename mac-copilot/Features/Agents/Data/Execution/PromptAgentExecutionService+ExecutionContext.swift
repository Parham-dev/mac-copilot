import Foundation

extension PromptAgentExecutionService {
    func buildExecutionContext(
        definition: AgentDefinition,
        inputPayload: [String: String]
    ) -> PromptExecutionContext {
        let requestedURL = inputPayload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let strictFetchMCP = shouldRequireFetchMCP(for: definition, requestedURL: requestedURL)

        let policyProfile: String
        if strictFetchMCP {
            policyProfile = "strict-fetch-mcp"
        } else {
            policyProfile = "default"
        }

        let skillNames = definition.optionalSkills
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let requireSkills = shouldRequireAgentSkills()
        let requestedOutputMode = requestedOutputMode(from: inputPayload)
        let requiredContract = requiredContract(for: definition, requestedOutputMode: requestedOutputMode)

        return PromptExecutionContext(
            agentID: definition.id,
            feature: "agents",
            policyProfile: policyProfile,
            skillNames: skillNames,
            requireSkills: requireSkills,
            requestedOutputMode: requestedOutputMode,
            requiredContract: requiredContract
        )
    }

    func requestedOutputMode(from inputPayload: [String: String]) -> String {
        let value = inputPayload["outputFormat"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            return "auto"
        }

        let normalized = value.lowercased()
        if normalized == "markdown brief" {
            return "markdown"
        }
        if normalized == "bullet" {
            return "text"
        }

        return normalized
    }

    func requiredContract(for definition: AgentDefinition, requestedOutputMode: String) -> String {
        let mode = requestedOutputMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mode == "json" else {
            return "none"
        }

        return "json"
    }

    func shouldRequireAgentSkills() -> Bool {
        let raw = ProcessInfo.processInfo.environment["COPILOTFORGE_REQUIRE_AGENT_SKILLS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if raw.isEmpty {
            return true
        }

        if ["1", "true", "yes", "on"].contains(raw) {
            return true
        }

        if ["0", "false", "no", "off"].contains(raw) {
            return false
        }

        return true
    }
}
