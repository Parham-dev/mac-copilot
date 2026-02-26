import Foundation

struct NodeControlCenterAdapter: ProjectControlCenterAdapter {
    let id: String = "node"
    let displayName: String = "Node"
    private let utilities = ControlCenterRuntimeUtilities()

    func makeLaunch(for project: ProjectRef) -> ControlCenterLaunch? {
        let root = utilities.expandedProjectURL(for: project)
        guard utilities.fileExists("package.json", in: root) else {
            return nil
        }

        let packageJSONURL = root.appendingPathComponent("package.json")
        let json = utilities.readJSON(at: packageJSONURL)
        let scripts = json?["scripts"] as? [String: Any] ?? [:]
        let preferredScript = scripts["dev"] != nil ? "dev" : (scripts["start"] != nil ? "start" : nil)

        let summary: String
        if let preferredScript {
            summary = "Found package.json with \(preferredScript) script in \(project.name)."
        } else {
            summary = "Found package.json in \(project.name)."
        }

        return ControlCenterLaunch(
            adapterID: id,
            adapterName: displayName,
            summary: summary,
            detail: packageJSONURL.path,
            actionTitle: "Open package.json",
            target: .file(packageJSONURL)
        )
    }
}

struct PythonProjectControlCenterAdapter: ProjectControlCenterAdapter {
    let id: String = "python"
    let displayName: String = "Python"
    private let utilities = ControlCenterRuntimeUtilities()

    func makeLaunch(for project: ProjectRef) -> ControlCenterLaunch? {
        let root = utilities.expandedProjectURL(for: project)

        let requirementsURL = root.appendingPathComponent("requirements.txt")
        let pyprojectURL = root.appendingPathComponent("pyproject.toml")
        let appURL = root.appendingPathComponent("app.py")

        let markerURL: URL
        let summary: String

        if utilities.fileExists("requirements.txt", in: root) {
            markerURL = requirementsURL
            summary = "Found requirements.txt in \(project.name)."
        } else if utilities.fileExists("pyproject.toml", in: root) {
            markerURL = pyprojectURL
            summary = "Found pyproject.toml in \(project.name)."
        } else if utilities.fileExists("app.py", in: root) {
            markerURL = appURL
            summary = "Found app.py in \(project.name)."
        } else {
            return nil
        }

        return ControlCenterLaunch(
            adapterID: id,
            adapterName: displayName,
            summary: summary,
            detail: markerURL.path,
            actionTitle: "Open project file",
            target: .file(markerURL)
        )
    }
}
