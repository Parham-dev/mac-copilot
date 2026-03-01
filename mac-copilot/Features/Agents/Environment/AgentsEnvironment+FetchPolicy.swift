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
        false
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
