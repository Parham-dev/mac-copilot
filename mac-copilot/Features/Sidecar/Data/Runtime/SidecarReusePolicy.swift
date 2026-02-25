import Foundation

enum SidecarHealthyReuseDecision: Equatable {
    case reuse
    case replace(String)
}

final class SidecarReusePolicy {
    private let runtimeTimestampProvider: SidecarRuntimeTimestampProvider

    init(runtimeTimestampProvider: SidecarRuntimeTimestampProvider = SidecarRuntimeTimestampProvider()) {
        self.runtimeTimestampProvider = runtimeTimestampProvider
    }

    func evaluate(
        healthSnapshot: SidecarHealthSnapshot?,
        minimumNodeMajorVersion: Int,
        localRuntimeScriptURL: URL
    ) -> SidecarHealthyReuseDecision {
        guard let healthSnapshot else {
            return .replace("healthy sidecar metadata is unavailable")
        }

        guard let version = healthSnapshot.nodeVersion,
              let major = parseNodeMajor(version)
        else {
            return .replace("running sidecar node version is missing")
        }

        guard major >= minimumNodeMajorVersion else {
            NSLog(
                "[CopilotForge] Running sidecar node runtime is incompatible (version=%@, exec=%@)",
                version,
                healthSnapshot.nodeExecPath ?? "unknown"
            )
            return .replace("running sidecar node runtime is incompatible")
        }

        guard let processStartedAtMs = healthSnapshot.processStartedAtMs, processStartedAtMs > 0 else {
            return .replace("running sidecar is missing process start metadata")
        }

        let localRuntimeUpdatedAtMs = runtimeTimestampProvider.latestRuntimeUpdatedAtMs(referenceScriptURL: localRuntimeScriptURL)
        if processStartedAtMs + 500 < localRuntimeUpdatedAtMs {
            return .replace("running sidecar started before the latest runtime build")
        }

        return .reuse
    }

    private func parseNodeMajor(_ versionString: String) -> Int? {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let numeric = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        guard let token = numeric.split(separator: ".").first,
              let major = Int(token)
        else {
            return nil
        }

        return major
    }
}
