import Foundation

enum LocalGitRepositoryParsing {
    static func parseBranchName(from statusHeaderLine: String) -> String {
        let header = statusHeaderLine
            .replacingOccurrences(of: "##", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if header.hasPrefix("No commits yet on ") {
            return String(header.dropFirst("No commits yet on ".count))
        }

        if header.hasPrefix("HEAD (no branch)") {
            return "Detached HEAD"
        }

        let branchPart = header
            .components(separatedBy: "...")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let branchPart, !branchPart.isEmpty else {
            return "Unknown"
        }

        return branchPart
    }

    static func mapFileState(stagedStatus: Character, unstagedStatus: Character) -> GitFileChangeState {
        let statuses = [stagedStatus, unstagedStatus]

        if statuses.contains("A") || statuses.contains("?") {
            return .added
        }

        if statuses.contains("D") {
            return .deleted
        }

        return .modified
    }

    static func parseNumStatMap(from output: String) -> [String: (added: Int, deleted: Int)] {
        let lines = output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        var map: [String: (added: Int, deleted: Int)] = [:]

        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }

            let addedLines = Int(parts[0]) ?? 0
            let deletedLines = Int(parts[1]) ?? 0
            let path = normalizePath(parts[2])
            guard !path.isEmpty else { continue }

            let existing = map[path] ?? (0, 0)
            map[path] = (existing.added + addedLines, existing.deleted + deletedLines)
        }

        return map
    }

    static func normalizePath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if let arrowRange = trimmed.range(of: " -> ", options: .backwards) {
            return String(trimmed[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return trimmed
    }

    static func countTextFileLinesIfPossible(repositoryPath: String, relativePath: String) -> Int? {
        let fileURL = URL(fileURLWithPath: repositoryPath).appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        if data.contains(0) {
            return nil
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var lineCount = 0
        text.enumerateLines { _, _ in
            lineCount += 1
        }

        return lineCount
    }
}
