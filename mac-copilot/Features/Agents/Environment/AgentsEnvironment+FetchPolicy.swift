import Foundation

extension AgentsEnvironment {
    func isFetchMCPTool(_ toolName: String) -> Bool {
        let normalized = normalizedToolName(toolName)
        return normalized == "fetch" || normalized == "fetch_fetch"
    }

    func isNativeWebFetchTool(_ toolName: String) -> Bool {
        let normalized = normalizedToolName(toolName)
        return normalized == "fetch_webpage" || normalized == "web_fetch"
    }

    func shouldRequireFetchMCP(for definition: AgentDefinition, requestedURL: String) -> Bool {
        guard definition.id == "url-summariser", !requestedURL.isEmpty else {
            return false
        }

        if let explicitRequire = readBooleanEnvironmentValue("COPILOTFORGE_REQUIRE_FETCH_MCP") {
            return explicitRequire
        }

        if let explicitAllowFallback = readBooleanEnvironmentValue("COPILOTFORGE_ALLOW_NATIVE_FETCH_FALLBACK") {
            return !explicitAllowFallback
        }

        return false
    }

    func readBooleanEnvironmentValue(_ key: String) -> Bool? {
        let raw = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if raw.isEmpty {
            return nil
        }

        if ["1", "true", "yes", "on"].contains(raw) {
            return true
        }

        if ["0", "false", "no", "off"].contains(raw) {
            return false
        }

        return nil
    }

    func normalizedToolName(_ toolName: String) -> String {
        let lowercased = toolName.lowercased()
        var normalized = ""
        var previousWasSeparator = false

        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                normalized.append("_")
                previousWasSeparator = true
            }
        }

        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
