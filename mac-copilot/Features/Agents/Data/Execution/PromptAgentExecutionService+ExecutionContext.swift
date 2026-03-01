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

        return PromptExecutionContext(
            agentID: definition.id,
            feature: "agents",
            policyProfile: policyProfile,
            skillNames: skillNames,
            requireSkills: requireSkills
        )
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
