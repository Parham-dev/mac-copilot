import Foundation

extension AgentsEnvironment {
    func prepareRunWorkspace(agentID: String, runID: UUID) -> (rootPath: String, runDirectoryPath: String) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let rootDirectory = appSupport
            .appendingPathComponent("CopilotForge", isDirectory: true)
            .appendingPathComponent("agents", isDirectory: true)
            .appendingPathComponent(agentID, isDirectory: true)

        let runDirectory = rootDirectory
            .appendingPathComponent("runs", isDirectory: true)
            .appendingPathComponent(runID.uuidString, isDirectory: true)

        do {
            try fileManager.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog(
                "[CopilotForge][AgentsEnvironment] failed to create run workspace agentID=%@ runID=%@ error=%@",
                agentID,
                runID.uuidString,
                error.localizedDescription
            )
        }

        return (rootDirectory.path, runDirectory.path)
    }

    func urlValueRequiringFetch(from inputPayload: [String: String]) -> String {
        let sourceKind = inputPayload["sourceKind"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let urlValue = inputPayload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !urlValue.isEmpty else { return "" }

        if sourceKind == "url" || sourceKind == "mixed" {
            return urlValue
        }

        if sourceKind == "text" || sourceKind == "files" {
            return ""
        }

        if let components = URLComponents(string: urlValue),
           let scheme = components.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           components.host?.isEmpty == false {
            return urlValue
        }

        if urlValue.lowercased().hasPrefix("www.") {
            return urlValue
        }

        return ""
    }

    func normalizedOutputMode(_ rawValue: String?) -> String {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if value.isEmpty {
            return "text"
        }

        switch value {
        case "markdown", "markdown brief":
            return "markdown"
        case "json":
            return "json"
        case "table":
            return "table"
        case "text", "bullet":
            return "text"
        default:
            return "text"
        }
    }
}
