import Foundation

protocol ProjectControlCenterAdapter {
    var id: String { get }
    var displayName: String { get }

    func makeLaunch(for project: ProjectRef) -> ControlCenterLaunch?
}
