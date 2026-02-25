import Foundation

protocol ControlCenterRuntimeAdapter {
    var id: String { get }
    var displayName: String { get }

    func canHandle(project: ProjectRef) -> Bool
    func makePlan(project: ProjectRef) throws -> ControlCenterRuntimePlan
}