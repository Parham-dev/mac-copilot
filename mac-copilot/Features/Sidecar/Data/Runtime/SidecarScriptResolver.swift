import Foundation

final class SidecarScriptResolver {
    func resolveSidecarScriptURL() -> URL? {
        if let bundledDist = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar/dist") {
            return bundledDist
        }

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        var searchCursor = sourceFileURL.deletingLastPathComponent()

        for _ in 0 ..< 12 {
            let distCandidate = searchCursor
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("dist", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false)

            if FileManager.default.fileExists(atPath: distCandidate.path) {
                NSLog("[CopilotForge] Using compiled sidecar source at %@", distCandidate.path)
                return distCandidate
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
