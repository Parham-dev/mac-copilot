import Foundation

extension PromptAgentExecutionService {
    func enrichInputPayloadIfNeeded(
        definition: AgentDefinition,
        inputPayload: [String: String],
        projectPath: String?
    ) -> [String: String] {
        guard definition.id == "project-health" else {
            return inputPayload
        }

        let resolvedPath = (inputPayload["projectPath"] ?? projectPath ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedPath.isEmpty else {
            return inputPayload
        }

        var payload = inputPayload
        let quickStats = buildProjectQuickStats(projectPath: resolvedPath)

        payload["quickStatsProjectPath"] = resolvedPath
        payload["quickStatsGeneratedAt"] = ISO8601DateFormatter().string(from: Date())
        payload["quickStatsTotalFiles"] = "\(quickStats.totalFiles)"
        payload["quickStatsTotalDirectories"] = "\(quickStats.totalDirectories)"
        payload["quickStatsTotalBytes"] = "\(quickStats.totalBytes)"
        payload["quickStatsTotalSizeHuman"] = quickStats.totalSizeHuman
        payload["quickStatsTopExtensions"] = quickStats.topExtensions
        payload["quickStatsLargestFiles"] = quickStats.largestFiles
        payload["quickStatsScanNotes"] = quickStats.scanNotes

        return payload
    }

    private func buildProjectQuickStats(projectPath: String) -> ProjectQuickStats {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: projectPath)

        let excludedDirectoryNames: Set<String> = [
            ".git", "node_modules", ".build", "DerivedData", ".swiftpm"
        ]

        var totalFiles = 0
        var totalDirectories = 0
        var totalBytes: Int64 = 0
        var extensionCounts: [String: Int] = [:]
        var largestFiles: [(path: String, size: Int64)] = []

        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .nameKey
        ]

        if let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: resourceKeys)
                    let name = values.name ?? fileURL.lastPathComponent

                    if values.isDirectory == true {
                        if excludedDirectoryNames.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }

                        totalDirectories += 1
                        continue
                    }

                    guard values.isRegularFile == true else {
                        continue
                    }

                    totalFiles += 1
                    let fileSize = Int64(values.fileSize ?? 0)
                    totalBytes += fileSize

                    let ext = fileURL.pathExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = ext.isEmpty ? "<no-ext>" : ext
                    extensionCounts[key, default: 0] += 1

                    let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                    largestFiles.append((path: relativePath, size: fileSize))
                } catch {
                    continue
                }
            }
        }

        let topExtensions = extensionCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(8)
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ", ")

        let largest = largestFiles
            .sorted { $0.size > $1.size }
            .prefix(5)
            .map { entry in
                "\(entry.path) (\(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)))"
            }
            .joined(separator: " | ")

        let totalSizeHuman = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let scanNotes = "Excluded directories: .git, node_modules, .build, DerivedData, .swiftpm"

        return ProjectQuickStats(
            totalFiles: totalFiles,
            totalDirectories: totalDirectories,
            totalBytes: totalBytes,
            totalSizeHuman: totalSizeHuman,
            topExtensions: topExtensions.isEmpty ? "<none>" : topExtensions,
            largestFiles: largest.isEmpty ? "<none>" : largest,
            scanNotes: scanNotes
        )
    }
}

private struct ProjectQuickStats {
    let totalFiles: Int
    let totalDirectories: Int
    let totalBytes: Int64
    let totalSizeHuman: String
    let topExtensions: String
    let largestFiles: String
    let scanNotes: String
}
