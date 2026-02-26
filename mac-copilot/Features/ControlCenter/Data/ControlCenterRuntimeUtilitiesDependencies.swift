import Foundation

protocol ControlCenterCommandRunning {
    func runCommand(executable: String, arguments: [String]) -> String
}

protocol ControlCenterFileManaging {
    func fileExists(atPath path: String) -> Bool
    func isExecutableFile(atPath path: String) -> Bool
    func htmlFilesRecursively(in directory: URL) -> [URL]
    func readData(at url: URL) -> Data?
}

protocol DateProviding {
    var now: Date { get }
}

struct ProcessControlCenterCommandRunner: ControlCenterCommandRunning {
    func runCommand(executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct FileManagerControlCenterFileManager: ControlCenterFileManaging {
    private let fileManager: FileManager = .default

    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    func isExecutableFile(atPath path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }

    func htmlFilesRecursively(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "html" {
            files.append(fileURL)
        }

        return files
    }

    func readData(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }
}

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}
