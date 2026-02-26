import Foundation
import Testing
@testable import mac_copilot

struct GitDomainPhase3Tests {
    @Test func parsing_branchNameHandlesEdgeCases() {
        #expect(LocalGitRepositoryParsing.parseBranchName(from: "## No commits yet on main") == "main")
        #expect(LocalGitRepositoryParsing.parseBranchName(from: "## HEAD (no branch)") == "Detached HEAD")
        #expect(LocalGitRepositoryParsing.parseBranchName(from: "## feature/refactor...origin/feature/refactor [ahead 1]") == "feature/refactor")
    }

    @Test func parsing_numstatAggregatesAndNormalizesRenamePaths() {
        let output = [
            "5\t2\tsrc/ViewModel.swift",
            "3\t1\tsrc/ViewModel.swift",
            "-\t-\told/name.txt -> new/name.txt"
        ].joined(separator: "\n")

        let map = LocalGitRepositoryParsing.parseNumStatMap(from: output)

        #expect(map["src/ViewModel.swift"]?.added == 8)
        #expect(map["src/ViewModel.swift"]?.deleted == 3)
        #expect(map["new/name.txt"]?.added == 0)
        #expect(map["new/name.txt"]?.deleted == 0)
    }

    @Test func parsing_fileStateMappingPrefersAddedThenDeletedThenModified() {
        #expect(LocalGitRepositoryParsing.mapFileState(stagedStatus: "A", unstagedStatus: " ") == .added)
        #expect(LocalGitRepositoryParsing.mapFileState(stagedStatus: " ", unstagedStatus: "?") == .added)
        #expect(LocalGitRepositoryParsing.mapFileState(stagedStatus: "D", unstagedStatus: " ") == .deleted)
        #expect(LocalGitRepositoryParsing.mapFileState(stagedStatus: "R", unstagedStatus: " ") == .modified)
    }

    @Test func manager_fileChangesMapsStatesAndUsesLineCountFallbackForAddedTextFile() async throws {
        let temp = try TemporaryRepo.make()
        defer { temp.cleanup() }

        let newFilePath = URL(fileURLWithPath: temp.path).appendingPathComponent("new.txt")
        try "one\ntwo\nthree\n".write(to: newFilePath, atomically: true, encoding: .utf8)

        let runner = FakeGitCommandRunner([
            ["-C", temp.path, "status", "--porcelain"]: GitCommandResult(
                terminationStatus: 0,
                output: [
                    "?? new.txt",
                    " M mod.swift",
                    "D  removed.md",
                    "R  old/name.txt -> new/name.txt"
                ].joined(separator: "\n")
            ),
            ["-C", temp.path, "diff", "--numstat"]: GitCommandResult(
                terminationStatus: 0,
                output: "2\t1\tmod.swift\n"
            ),
            ["-C", temp.path, "diff", "--cached", "--numstat"]: GitCommandResult(
                terminationStatus: 0,
                output: "0\t4\tremoved.md\n1\t0\told/name.txt -> new/name.txt\n"
            )
        ])

        let manager = LocalGitRepositoryManager(commandRunner: runner, fileSystem: FakeGitFileSystem(exists: false))
        let changes = try await manager.fileChanges(at: temp.path)

        #expect(changes.count == 4)

        let newFile = try #require(changes.first(where: { $0.path == "new.txt" }))
        #expect(newFile.state == .added)
        #expect(newFile.addedLines == 3)
        #expect(newFile.deletedLines == 0)

        let modified = try #require(changes.first(where: { $0.path == "mod.swift" }))
        #expect(modified.state == .modified)
        #expect(modified.addedLines == 2)
        #expect(modified.deletedLines == 1)

        let deleted = try #require(changes.first(where: { $0.path == "removed.md" }))
        #expect(deleted.state == .deleted)
        #expect(deleted.addedLines == 0)
        #expect(deleted.deletedLines == 4)

        let renamed = try #require(changes.first(where: { $0.path == "new/name.txt" }))
        #expect(renamed.state == .modified)
        #expect(renamed.addedLines == 1)
        #expect(renamed.deletedLines == 0)
    }

    @Test func manager_commitRejectsEmptyMessage() async {
        let manager = LocalGitRepositoryManager(
            commandRunner: FakeGitCommandRunner([:]),
            fileSystem: FakeGitFileSystem(exists: false)
        )

        await #expect(throws: GitRepositoryError.self) {
            try await manager.commit(at: "/tmp/repo", message: "   \n")
        }
    }

    @Test func manager_commitThrowsWhenStagingFails() async {
        let path = "/tmp/repo"
        let runner = FakeGitCommandRunner([
            ["-C", path, "add", "-A"]: GitCommandResult(terminationStatus: 1, output: "index.lock exists")
        ])
        let manager = LocalGitRepositoryManager(commandRunner: runner, fileSystem: FakeGitFileSystem(exists: false))

        await #expect(throws: GitRepositoryError.self) {
            try await manager.commit(at: path, message: "msg")
        }

        #expect(runner.calls.count == 1)
        #expect(runner.calls.first == ["-C", path, "add", "-A"])
    }

    @Test func manager_commitThrowsWhenCommitCommandFails() async {
        let path = "/tmp/repo"
        let runner = FakeGitCommandRunner([
            ["-C", path, "add", "-A"]: GitCommandResult(terminationStatus: 0, output: ""),
            ["-C", path, "commit", "-m", "msg"]: GitCommandResult(terminationStatus: 1, output: "nothing to commit")
        ])
        let manager = LocalGitRepositoryManager(commandRunner: runner, fileSystem: FakeGitFileSystem(exists: false))

        await #expect(throws: GitRepositoryError.self) {
            try await manager.commit(at: path, message: "msg")
        }

        #expect(runner.calls.count == 2)
        #expect(runner.calls[0] == ["-C", path, "add", "-A"])
        #expect(runner.calls[1] == ["-C", path, "commit", "-m", "msg"])
    }
}

private final class FakeGitCommandRunner: GitCommandRunning {
    private let responses: [String: GitCommandResult]
    private(set) var calls: [[String]] = []

    init(_ responses: [[String]: GitCommandResult]) {
        self.responses = Dictionary(uniqueKeysWithValues: responses.map { (Self.key(for: $0.key), $0.value) })
    }

    func runGit(arguments: [String]) -> GitCommandResult {
        calls.append(arguments)
        return responses[Self.key(for: arguments)] ?? GitCommandResult(terminationStatus: 0, output: "")
    }

    private static func key(for arguments: [String]) -> String {
        arguments.joined(separator: "\u{001F}")
    }
}

private struct FakeGitFileSystem: GitFileSystemChecking {
    let exists: Bool

    func fileExists(atPath path: String) -> Bool {
        exists
    }
}

private struct TemporaryRepo {
    let path: String

    static func make() throws -> TemporaryRepo {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("git-phase3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return TemporaryRepo(path: directory.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: path)
    }
}