import Foundation

struct SimpleHTMLControlCenterAdapter: ProjectControlCenterAdapter {
    let id: String = "simple-html"
    let displayName: String = "Simple HTML"

    func makeLaunch(for project: ProjectRef) -> ControlCenterLaunch? {
        guard let htmlURL = findHTMLFile(in: project.localPath) else {
            return nil
        }

        return ControlCenterLaunch(
            adapterID: id,
            adapterName: displayName,
            summary: "Found HTML file in \(project.name).",
            detail: htmlURL.path,
            actionTitle: "Open in Browser",
            target: .file(htmlURL)
        )
    }

    private func findHTMLFile(in projectPath: String) -> URL? {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        let fileManager = FileManager.default

        let indexURL = baseURL.appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: indexURL.path) {
            return indexURL
        }

        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "html" else { continue }
            return fileURL
        }

        return nil
    }
}
