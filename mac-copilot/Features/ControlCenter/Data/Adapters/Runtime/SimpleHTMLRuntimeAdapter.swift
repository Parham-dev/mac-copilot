import Foundation

struct SimpleHTMLRuntimeAdapter: ControlCenterRuntimeAdapter {
    let id: String = "simple-html"
    let displayName: String = "Simple HTML"
    private let utilities = ControlCenterRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.firstHTMLFile(in: root) != nil
    }

    func makePlan(project: ProjectRef) throws -> ControlCenterRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let htmlURL = utilities.firstHTMLFile(in: root) else {
            throw NSError(domain: "ControlCenter", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No HTML file found for Control Center."])
        }

        return ControlCenterRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .directOpen(target: htmlURL)
        )
    }
}
