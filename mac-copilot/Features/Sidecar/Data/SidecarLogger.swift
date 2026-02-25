import Foundation

final class SidecarLogger {
    func log(_ message: String, runID: String?) {
        if let runID {
            NSLog("[CopilotForge][Sidecar][run:%@] %@", runID, message)
        } else {
            NSLog("[CopilotForge][Sidecar] %@", message)
        }
    }
}
