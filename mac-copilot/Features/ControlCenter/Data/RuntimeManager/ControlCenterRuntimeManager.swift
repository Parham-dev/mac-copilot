import Foundation
import AppKit
import Combine
import Darwin

@MainActor
final class ControlCenterRuntimeManager: ObservableObject {
    @Published var state: ControlCenterRuntimeState = .idle
    @Published var adapterName: String?
    @Published var activeURL: URL?
    @Published var logs: [String] = []
    @Published var activeProjectID: UUID?

    let adapters: [any ControlCenterRuntimeAdapter]
    let utilities: ControlCenterRuntimeUtilities
    let healthTransport: HTTPDataTransporting
    let delayScheduler: AsyncDelayScheduling
    let clock: ClockProviding
    let commandRunner: ControlCenterCommandStatusRunning

    var process: Process?
    var stdoutPipe: Pipe?
    var stderrPipe: Pipe?
    var logEntries: [RuntimeLogEntry] = []
    var isStopRequested = false
    var shouldResetUIAfterStop = false
    var shouldClearLogsAfterStop = false

    let maxUILogLines = 200
    let maxDiagnosticLogEntries = 800
    let failedPortReservationTTL: TimeInterval = 90
    let gracefulStopTimeout: TimeInterval = 1.5

    enum LogPhase: String {
        case lifecycle
        case install
        case start
        case runtime
        case health
    }

    enum LogStream: String {
        case system
        case stdout
        case stderr
    }

    struct RuntimeLogEntry {
        let timestamp: Date
        let phase: LogPhase
        let stream: LogStream
        let message: String
    }

    struct RuntimeContext {
        let project: ProjectRef
        let adapter: any ControlCenterRuntimeAdapter
        let plan: ControlCenterRuntimePlan
    }

    enum RuntimeError: Error {
        case noAdapter
    }

    enum LaunchHealthResult: Equatable {
        case healthy
        case unhealthy(failedPort: Int?)
    }

    init(
        adapters: [any ControlCenterRuntimeAdapter],
        utilities: ControlCenterRuntimeUtilities? = nil,
        healthTransport: HTTPDataTransporting? = nil,
        delayScheduler: AsyncDelayScheduling? = nil,
        clock: ClockProviding? = nil,
        commandRunner: ControlCenterCommandStatusRunning? = nil
    ) {
        self.adapters = adapters
        self.utilities = utilities ?? ControlCenterRuntimeUtilities()
        self.healthTransport = healthTransport ?? URLSessionHTTPDataTransport()
        self.delayScheduler = delayScheduler ?? TaskAsyncDelayScheduler()
        self.clock = clock ?? SystemClockProvider()
        self.commandRunner = commandRunner ?? ProcessControlCenterCommandStatusRunner()
    }

    var isBusy: Bool {
        switch state {
        case .installing, .starting:
            return true
        case .idle, .running, .failed:
            return false
        }
    }

    var isRunning: Bool {
        state == .running
    }

    func start(project: ProjectRef, autoOpen: Bool = true) {
        Task {
            await startInternal(project: project, autoOpen: autoOpen, isRefresh: false)
        }
    }

    func refresh(project: ProjectRef) {
        Task {
            await startInternal(project: project, autoOpen: true, isRefresh: true)
        }
    }

    func stop(resetUI: Bool = true, clearLogsWhenClean: Bool = true) {
        let hadFailure: Bool
        if case .failed = state {
            hadFailure = true
        } else {
            hadFailure = false
        }

        isStopRequested = true
        shouldResetUIAfterStop = resetUI
        shouldClearLogsAfterStop = clearLogsWhenClean && !hadFailure

        guard let runningProcess = process else {
            if shouldResetUIAfterStop {
                activeURL = nil
                adapterName = nil
                activeProjectID = nil
            }

            if shouldClearLogsAfterStop {
                logs.removeAll(keepingCapacity: true)
                logEntries.removeAll(keepingCapacity: true)
            }

            isStopRequested = false
            shouldResetUIAfterStop = false
            shouldClearLogsAfterStop = false
            state = .idle
            return
        }

        runningProcess.terminate()
        scheduleForceKillIfNeeded(for: runningProcess)
        state = .idle

        if hadFailure {
            appendLog("Stopping control center runtime...", phase: .lifecycle)
        }
    }

    func openInBrowser() {
        guard let activeURL else { return }
        NSWorkspace.shared.open(activeURL)
    }

    private func scheduleForceKillIfNeeded(for runningProcess: Process) {
        let targetPID = runningProcess.processIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await delayScheduler.sleep(seconds: gracefulStopTimeout)

            guard isStopRequested,
                  let current = process,
                  current.processIdentifier == targetPID,
                  current.isRunning
            else {
                return
            }

            Darwin.kill(targetPID, SIGKILL)
        }
    }
}
