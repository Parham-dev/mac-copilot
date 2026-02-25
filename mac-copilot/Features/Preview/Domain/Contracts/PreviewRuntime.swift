import Foundation

protocol PreviewRuntimeAdapter {
    var id: String { get }
    var displayName: String { get }

    func canHandle(project: ProjectRef) -> Bool
    func makePlan(project: ProjectRef) throws -> PreviewRuntimePlan
}