import Foundation

protocol PreviewRuntimeAdapter {
    var id: String { get }
    var displayName: String { get }

    func canHandle(project: ProjectRef, utilities: PreviewRuntimeUtilities) -> Bool
    func makePlan(project: ProjectRef, utilities: PreviewRuntimeUtilities) throws -> PreviewRuntimePlan
}