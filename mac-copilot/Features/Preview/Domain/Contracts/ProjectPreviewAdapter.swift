import Foundation

protocol ProjectPreviewAdapter {
    var id: String { get }
    var displayName: String { get }

    func makeLaunch(for project: ProjectRef) -> PreviewLaunch?
}
