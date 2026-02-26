import Foundation

struct SimpleHTMLControlCenterAdapter: ProjectControlCenterAdapter {
    let id: String = "simple-html"
    let displayName: String = "Simple HTML"
    private let fileManager: ControlCenterFileManaging

    init(fileManager: ControlCenterFileManaging = FileManagerControlCenterFileManager()) {
        self.fileManager = fileManager
    }

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

        let indexURL = baseURL.appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: indexURL.path) {
            return indexURL
        }

        return fileManager.htmlFilesRecursively(in: baseURL).first
    }
}
