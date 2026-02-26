import Foundation

struct GitRepositoryError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

final class LocalGitRepositoryManager: GitRepositoryManaging {
    private let commandRunner: GitCommandRunning

    init(commandRunner: GitCommandRunning = LocalGitCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func isGitRepository(at path: String) async -> Bool {
        await runInBackground {
            let gitURL = URL(fileURLWithPath: path).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path) {
                return true
            }

            let result = self.commandRunner.runGit(arguments: ["-C", path, "rev-parse", "--is-inside-work-tree"])
            guard result.terminationStatus == 0 else {
                return false
            }

            return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
    }

    func initializeRepository(at path: String) async throws {
        let result = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "init"])
        }

        if result.terminationStatus == 0 {
            return
        }

        let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        throw GitRepositoryError(message: message.isEmpty ? "Could not initialize Git repository." : message)
    }

    func repositoryStatus(at path: String) async throws -> GitRepositoryStatus {
        let result = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "status", "--porcelain", "--branch"])
        }

        guard result.terminationStatus == 0 else {
            let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitRepositoryError(message: message.isEmpty ? "Could not read Git repository status." : message)
        }

        let lines = result.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        guard let headerLine = lines.first, headerLine.hasPrefix("##") else {
            throw GitRepositoryError(message: "Could not determine current Git branch.")
        }

        let branchName = LocalGitRepositoryParsing.parseBranchName(from: headerLine)
        let changedFilesCount = max(lines.count - 1, 0)

        return GitRepositoryStatus(
            branchName: branchName,
            changedFilesCount: changedFilesCount,
            repositoryPath: path
        )
    }

    func fileChanges(at path: String) async throws -> [GitFileChange] {
        let statusResult = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "status", "--porcelain"])
        }

        guard statusResult.terminationStatus == 0 else {
            let message = statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitRepositoryError(message: message.isEmpty ? "Could not read Git file changes." : message)
        }

        let unstagedNumStatResult = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "diff", "--numstat"])
        }
        let stagedNumStatResult = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "diff", "--cached", "--numstat"])
        }

        let unstagedLineCounts = LocalGitRepositoryParsing.parseNumStatMap(from: unstagedNumStatResult.output)
        let stagedLineCounts = LocalGitRepositoryParsing.parseNumStatMap(from: stagedNumStatResult.output)

        let lines = statusResult.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        return lines.compactMap { line in
            parseGitFileChange(
                from: line,
                repositoryPath: path,
                stagedLineCounts: stagedLineCounts,
                unstagedLineCounts: unstagedLineCounts
            )
        }
    }

    func recentCommits(at path: String, limit: Int) async throws -> [GitRecentCommit] {
        let result = await runInBackground {
            self.commandRunner.runGit(arguments: [
                "-C", path,
                "log",
                "-n", String(max(limit, 1)),
                "--pretty=format:%h%x09%an%x09%ar%x09%s"
            ])
        }

        if result.terminationStatus != 0 {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.localizedCaseInsensitiveContains("does not have any commits yet") {
                return []
            }

            throw GitRepositoryError(message: output.isEmpty ? "Could not read recent commits." : output)
        }

        let lines = result.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        return lines.compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 4 else { return nil }

            return GitRecentCommit(
                shortHash: parts[0],
                author: parts[1],
                relativeTime: parts[2],
                message: parts[3]
            )
        }
    }

    func commit(at path: String, message: String) async throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw GitRepositoryError(message: "Commit message cannot be empty.")
        }

        let stageResult = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "add", "-A"])
        }

        guard stageResult.terminationStatus == 0 else {
            let message = stageResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitRepositoryError(message: message.isEmpty ? "Could not stage Git changes." : message)
        }

        let result = await runInBackground {
            self.commandRunner.runGit(arguments: ["-C", path, "commit", "-m", trimmedMessage])
        }

        guard result.terminationStatus == 0 else {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = output.isEmpty ? "Could not commit Git changes." : output
            throw GitRepositoryError(message: fallback)
        }
    }

    private func runInBackground<T>(_ operation: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: operation())
            }
        }
    }

    private func parseGitFileChange(
        from line: String,
        repositoryPath: String,
        stagedLineCounts: [String: (added: Int, deleted: Int)],
        unstagedLineCounts: [String: (added: Int, deleted: Int)]
    ) -> GitFileChange? {
        guard line.count >= 3 else { return nil }

        let chars = Array(line)
        let stagedStatus = chars[0]
        let unstagedStatus = chars[1]

        let rawPath = String(chars.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let path = LocalGitRepositoryParsing.normalizePath(rawPath)
        guard !path.isEmpty else { return nil }

        let stagedStats = stagedLineCounts[path] ?? (0, 0)
        let unstagedStats = unstagedLineCounts[path] ?? (0, 0)
        let state = LocalGitRepositoryParsing.mapFileState(stagedStatus: stagedStatus, unstagedStatus: unstagedStatus)

        var addedLines = stagedStats.added + unstagedStats.added
        let deletedLines = stagedStats.deleted + unstagedStats.deleted

        if state == .added,
           addedLines == 0,
           deletedLines == 0,
           let textLineCount = LocalGitRepositoryParsing.countTextFileLinesIfPossible(repositoryPath: repositoryPath, relativePath: path) {
            addedLines = textLineCount
        }

        return GitFileChange(
            path: path,
            state: state,
            addedLines: addedLines,
            deletedLines: deletedLines,
            isStaged: stagedStatus != " ",
            isUnstaged: unstagedStatus != " "
        )
    }

}
