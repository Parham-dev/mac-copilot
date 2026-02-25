import Foundation

enum SidecarState: Equatable {
    case stopped
    case starting
    case healthy
    case degraded
    case restarting
    case failed(String)
}

final class SidecarStateMachine {
    private(set) var state: SidecarState = .stopped

    func isHealthyRunning(processIsRunning: Bool) -> Bool {
        processIsRunning && state == .healthy
    }

    func canRestartWhileNotStarting(isStarting: Bool) -> Bool {
        state != .restarting && !isStarting
    }

    func transition(to next: SidecarState, log: (String) -> Void) {
        guard next != state else { return }
        state = next
        log("State => \(describe(state: next))")
    }

    func handleTermination(_ termination: SidecarProcessTermination, log: (String) -> Void) -> Bool {
        log("Sidecar terminated (reason=\(termination.reasonRawValue), status=\(termination.status))")

        if termination.intentional {
            log("Intentional sidecar termination acknowledged")
            if case .restarting = state {
                transition(to: .stopped, log: log)
            }
            return false
        }

        if state == .healthy || state == .starting {
            transition(to: .degraded, log: log)
            return true
        }

        if case .restarting = state {
            transition(to: .stopped, log: log)
        }

        return false
    }

    private func describe(state: SidecarState) -> String {
        switch state {
        case .stopped:
            return "stopped"
        case .starting:
            return "starting"
        case .healthy:
            return "healthy"
        case .degraded:
            return "degraded"
        case .restarting:
            return "restarting"
        case .failed(let message):
            return "failed(\(message))"
        }
    }
}
