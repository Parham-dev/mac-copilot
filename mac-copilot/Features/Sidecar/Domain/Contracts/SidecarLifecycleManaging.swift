import Foundation

protocol SidecarLifecycleManaging: AnyObject {
    func startIfNeeded()
    func restart()
    func stop()
}
