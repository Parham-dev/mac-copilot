import Foundation
import AppKit

extension ControlCenterRuntimeManager {
    func startInternal(project: ProjectRef, autoOpen: Bool, isRefresh: Bool) async {
        do {
            prepareForStart(project: project, isRefresh: isRefresh)
            let context = try makeRuntimeContext(for: project)
            try await execute(plan: context.plan, adapter: context.adapter, project: project, autoOpen: autoOpen)
        } catch {
            failWithError("Control center failed: \(error.localizedDescription)")
        }
    }

    func prepareForStart(project: ProjectRef, isRefresh: Bool) {
        if isRefresh {
            appendLog("Refreshing control center for \(project.name)", phase: .lifecycle)
            stop()
        } else if activeProjectID != nil, activeProjectID != project.id {
            appendLog("Switching control center runtime to \(project.name)", phase: .lifecycle)
            stop()
        }

        activeProjectID = project.id
        activeURL = nil
        logs.removeAll(keepingCapacity: true)
        logEntries.removeAll(keepingCapacity: true)
    }

    func makeRuntimeContext(for project: ProjectRef) throws -> RuntimeContext {
        guard let adapter = adapters.first(where: { $0.canHandle(project: project) }) else {
            state = .failed("No control center adapter supports this project yet")
            appendLog("No adapter matched project", phase: .lifecycle)
            throw RuntimeError.noAdapter
        }

        adapterName = adapter.displayName
        appendLog("Using adapter: \(adapter.displayName)", phase: .lifecycle)

        let plan = try adapter.makePlan(project: project)
        return RuntimeContext(project: project, adapter: adapter, plan: plan)
    }

    func execute(
        plan: ControlCenterRuntimePlan,
        adapter: any ControlCenterRuntimeAdapter,
        project: ProjectRef,
        autoOpen: Bool
    ) async throws {
        switch plan.mode {
        case .directOpen(let target):
            completeDirectOpen(target: target, autoOpen: autoOpen)

        case .managedServer(
            let install,
            let start,
            let healthURL,
            let openURL,
            let bootTimeoutSeconds,
            let environment
        ):
            let result = try await runManagedServer(
                install: install,
                start: start,
                healthURL: healthURL,
                openURL: openURL,
                bootTimeoutSeconds: bootTimeoutSeconds,
                environment: environment,
                workingDirectory: plan.workingDirectory,
                autoOpen: autoOpen
            )

            guard case .unhealthy(let failedPort) = result,
                  let failedPort,
                  failedPort > 0 else {
                return
            }

            try await retryManagedServerStart(
                failedPort: failedPort,
                adapter: adapter,
                project: project,
                autoOpen: autoOpen
            )
        }
    }

    func completeDirectOpen(target: URL, autoOpen: Bool) {
        state = .running
        activeURL = target
        appendLog("Ready: \(target.absoluteString)", phase: .lifecycle)
        if autoOpen {
            NSWorkspace.shared.open(target)
        }
    }

    func runManagedServer(
        install: ControlCenterCommand?,
        start: ControlCenterCommand,
        healthURL: URL,
        openURL: URL,
        bootTimeoutSeconds: TimeInterval,
        environment: [String: String],
        workingDirectory: URL,
        autoOpen: Bool
    ) async throws -> LaunchHealthResult {
        if let install {
            let installed = try await performInstallIfNeeded(
                command: install,
                workingDirectory: workingDirectory,
                environment: environment
            )
            if !installed {
                return .unhealthy(failedPort: nil)
            }
        }

        state = .starting
        appendLog("Starting server...", phase: .start)
        return try await launchAndAwaitHealth(
            start: start,
            cwd: workingDirectory,
            environment: environment,
            healthURL: healthURL,
            bootTimeoutSeconds: bootTimeoutSeconds,
            openURL: openURL,
            autoOpen: autoOpen
        )
    }

    func performInstallIfNeeded(
        command: ControlCenterCommand,
        workingDirectory: URL,
        environment: [String: String]
    ) async throws -> Bool {
        state = .installing
        appendLog("Installing dependencies...", phase: .install)

        let installResult = try await runAndCapture(
            command: command,
            cwd: workingDirectory,
            environment: environment
        )

        if installResult.exitCode != 0 {
            state = .failed("Dependency installation failed")
            appendLog(installResult.output, phase: .install, stream: .stderr)
            return false
        }

        if !installResult.output.isEmpty {
            appendLog(installResult.output, phase: .install)
        }

        return true
    }

    func retryManagedServerStart(
        failedPort: Int,
        adapter: any ControlCenterRuntimeAdapter,
        project: ProjectRef,
        autoOpen: Bool
    ) async throws {
        appendLog("Port \(failedPort) failed to start cleanly. Retrying on a new port...", phase: .health)
        utilities.reservePortTemporarily(failedPort, ttlSeconds: failedPortReservationTTL)
        stop()

        let retryPlan = try adapter.makePlan(project: project)
        guard case .managedServer(_, let retryStart, let retryHealthURL, let retryOpenURL, let retryBootTimeout, let retryEnvironment) = retryPlan.mode else {
            state = .failed("Retry planning failed")
            appendLog("Adapter returned non-server plan on retry", phase: .lifecycle)
            return
        }

        state = .starting
        appendLog("Retrying start on \(retryHealthURL.absoluteString)", phase: .start)

        let retryResult = try await launchAndAwaitHealth(
            start: retryStart,
            cwd: retryPlan.workingDirectory,
            environment: retryEnvironment,
            healthURL: retryHealthURL,
            bootTimeoutSeconds: retryBootTimeout,
            openURL: retryOpenURL,
            autoOpen: autoOpen
        )

        guard retryResult != .healthy else {
            return
        }

        state = .failed("Server did not become healthy in time")
        appendLog("Retry health check failed for \(retryHealthURL.absoluteString)", phase: .health)
        stop()
    }
}
