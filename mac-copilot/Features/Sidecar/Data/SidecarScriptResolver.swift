import Foundation

final class SidecarScriptResolver {
    func resolveSidecarScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar") {
            return bundled
        }

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        var searchCursor = sourceFileURL.deletingLastPathComponent()

        for _ in 0 ..< 12 {
            let candidate = searchCursor
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false)

            if FileManager.default.fileExists(atPath: candidate.path) {
                NSLog("[CopilotForge] Using local sidecar source at %@", candidate.path)
                return candidate
            }

            let parent = searchCursor.deletingLastPathComponent()
            if parent.path == searchCursor.path {
                break
            }
            searchCursor = parent
        }

        return nil
    }
}
