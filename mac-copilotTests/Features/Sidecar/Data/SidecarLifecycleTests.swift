import Foundation
import Testing
@testable import mac_copilot

struct SidecarLifecycleTests {
    @Test func restartPolicy_backoffAndJitterAreDeterministicWhenInjected() {
        let policy = SidecarRestartPolicy(
            maxRestartsInWindow: 4,
            restartWindowSeconds: 60,
            maximumBackoffSeconds: 8,
            jitterProvider: { 0.2 }
        )

        #expect(policy.nextRetryDelay() == 2.2)
        #expect(policy.nextRetryDelay() == 4.2)
        #expect(policy.nextRetryDelay() == 8.2)
        #expect(policy.nextRetryDelay() == 8.2)

        policy.resetRetryAttempt()
        #expect(policy.nextRetryDelay() == 2.2)
    }

    @Test func restartPolicy_windowGuardBlocksAndThenRecovers() {
        let policy = SidecarRestartPolicy(maxRestartsInWindow: 2, restartWindowSeconds: 60, jitterProvider: { 0 })
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(policy.canAttemptRestart(now: base))
        #expect(policy.canAttemptRestart(now: base.addingTimeInterval(1)))
        #expect(!policy.canAttemptRestart(now: base.addingTimeInterval(2)))
        #expect(policy.canAttemptRestart(now: base.addingTimeInterval(61)))
    }

    @Test func stateMachine_crashDuringHealthyTransitionsToDegradedAndRequestsRetry() {
        let machine = SidecarStateMachine()
        var logs: [String] = []
        machine.transition(to: .healthy) { logs.append($0) }

        let shouldRetry = machine.handleTermination(
            SidecarProcessTermination(reasonRawValue: 1, status: 1, processIdentifier: 42, intentional: false),
            log: { logs.append($0) }
        )

        #expect(shouldRetry)
        #expect(machine.state == .degraded)
    }

    @Test func stateMachine_intentionalTerminationDuringRestartStopsWithoutRetry() {
        let machine = SidecarStateMachine()
        machine.transition(to: .restarting) { _ in }

        let shouldRetry = machine.handleTermination(
            SidecarProcessTermination(reasonRawValue: 1, status: 0, processIdentifier: 42, intentional: true),
            log: { _ in }
        )

        #expect(!shouldRetry)
        #expect(machine.state == .stopped)
    }

    @Test func sidecarManager_reusesHealthyExternalSidecarWithoutLaunchingProcess() async {
        let preflight = FakePreflight.success()
        let runtime = FakeRuntimeUtilities()
        runtime.healthyResults[2] = true
        runtime.reuseDecision = .reuse
        let process = FakeProcessController()
        let restart = FakeRestartPolicy(canAttemptResults: [true])
        let logger = FakeLogger()
        let scheduler = ScheduledOperationRecorder()

        let manager = SidecarManager(
            queue: DispatchQueue(label: "tests.sidecar.manager.reuse"),
            preflight: preflight,
            runtimeUtilities: runtime,
            processController: process,
            restartPolicy: restart,
            logger: logger,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            scheduleAfter: scheduler.schedule
        )

        manager.startIfNeeded()

        let completed = await eventually { logger.contains("reusing it") }
        #expect(completed)
        #expect(process.startCalls == 0)
        #expect(restart.canAttemptCallCount == 0)
    }

    @Test func sidecarManager_clearsStaleHandleAndStartsProcess() async {
        let preflight = FakePreflight.success()
        let runtime = FakeRuntimeUtilities()
        runtime.waitForHealthyResult = true
        let process = FakeProcessController()
        process.staleHandle = true
        let restart = FakeRestartPolicy(canAttemptResults: [true])
        let logger = FakeLogger()

        let manager = SidecarManager(
            queue: DispatchQueue(label: "tests.sidecar.manager.stale"),
            preflight: preflight,
            runtimeUtilities: runtime,
            processController: process,
            restartPolicy: restart,
            logger: logger,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            scheduleAfter: { _, _ in }
        )

        manager.startIfNeeded()

        let completed = await eventually { process.startCalls == 1 }
        #expect(completed)
        #expect(process.clearStaleCalls == 1)
    }

    @Test func sidecarManager_failedReadinessSchedulesRetryWhenAllowed() async {
        let preflight = FakePreflight.success()
        let runtime = FakeRuntimeUtilities()
        runtime.waitForHealthyResult = false
        let process = FakeProcessController()
        let restart = FakeRestartPolicy(canAttemptResults: [true, true], nextDelay: 1.75)
        let logger = FakeLogger()
        let scheduler = ScheduledOperationRecorder()

        let manager = SidecarManager(
            queue: DispatchQueue(label: "tests.sidecar.manager.retry"),
            preflight: preflight,
            runtimeUtilities: runtime,
            processController: process,
            restartPolicy: restart,
            logger: logger,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            scheduleAfter: scheduler.schedule
        )

        manager.startIfNeeded()

        let completed = await eventually { scheduler.delays.count == 1 }
        #expect(completed)
        #expect(process.stopCalls == 1)
        #expect(scheduler.delays.first == 1.75)
        #expect(logger.contains("Scheduling sidecar retry"))
    }

    @Test func sidecarManager_failedReadinessMarksFailedWhenRetryGuardTrips() async {
        let preflight = FakePreflight.success()
        let runtime = FakeRuntimeUtilities()
        runtime.waitForHealthyResult = false
        let process = FakeProcessController()
        let restart = FakeRestartPolicy(canAttemptResults: [true, false], nextDelay: 1.5)
        let logger = FakeLogger()
        let scheduler = ScheduledOperationRecorder()

        let manager = SidecarManager(
            queue: DispatchQueue(label: "tests.sidecar.manager.guard"),
            preflight: preflight,
            runtimeUtilities: runtime,
            processController: process,
            restartPolicy: restart,
            logger: logger,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            scheduleAfter: scheduler.schedule
        )

        manager.startIfNeeded()

        let completed = await eventually { logger.contains("Retry skipped: restart guard tripped") }
        #expect(completed)
        #expect(scheduler.delays.isEmpty)
    }

    @Test func sidecarManager_crashTerminationSchedulesRetry_butIntentionalDoesNot() async {
        let preflight = FakePreflight.success()
        let runtime = FakeRuntimeUtilities()
        runtime.waitForHealthyResult = true
        let process = FakeProcessController()
        let restart = FakeRestartPolicy(canAttemptResults: [true, true], nextDelay: 2.0)
        let logger = FakeLogger()
        let scheduler = ScheduledOperationRecorder()

        let manager = SidecarManager(
            queue: DispatchQueue(label: "tests.sidecar.manager.termination"),
            preflight: preflight,
            runtimeUtilities: runtime,
            processController: process,
            restartPolicy: restart,
            logger: logger,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            scheduleAfter: scheduler.schedule
        )

        manager.startIfNeeded()
        let started = await eventually { process.startCalls == 1 }
        #expect(started)

        process.emitTermination(intentional: false, status: 1)
        let crashScheduled = await eventually { scheduler.delays.count == 1 }
        #expect(crashScheduled)

        process.emitTermination(intentional: true, status: 0)
        try? await Task.sleep(nanoseconds: 80_000_000)
        #expect(scheduler.delays.count == 1)
    }
}

// MARK: - Sidecar-domain test doubles

private struct FixedClock: ClockProviding {
    let now: Date
}

private final class ScheduledOperationRecorder {
    private(set) var delays: [TimeInterval] = []

    func schedule(delay: TimeInterval, operation: @escaping () -> Void) {
        delays.append(delay)
        _ = operation
    }
}

private final class FakeLogger: SidecarLogWriting {
    private(set) var entries: [String] = []

    func log(_ message: String, runID: String?) {
        entries.append(message)
    }

    func contains(_ fragment: String) -> Bool {
        entries.contains(where: { $0.localizedCaseInsensitiveContains(fragment) })
    }
}

private final class FakePreflight: SidecarPreflightChecking {
    private let startup: SidecarStartupConfig

    init(startup: SidecarStartupConfig) {
        self.startup = startup
    }

    static func success() -> FakePreflight {
        FakePreflight(
            startup: SidecarStartupConfig(
                scriptURL: URL(fileURLWithPath: "/tmp/sidecar/index.js"),
                nodeExecutable: URL(fileURLWithPath: "/opt/homebrew/bin/node"),
                nodeVersion: "v22.8.0"
            )
        )
    }

    func check() throws -> SidecarStartupConfig {
        startup
    }
}

private final class FakeRuntimeUtilities: SidecarRuntimeUtilityManaging {
    var healthyResults: [Int: Bool] = [1: false, 2: false]
    var waitForHealthyResult = false
    var reuseDecision: SidecarHealthyReuseDecision = .replace("replace")
    private(set) var terminateCalls: [String] = []

    func isHealthySidecarAlreadyRunning(requiredSuccesses: Int) -> Bool {
        healthyResults[requiredSuccesses] ?? false
    }

    func waitForHealthySidecar(timeout: TimeInterval) -> Bool {
        _ = timeout
        return waitForHealthyResult
    }

    func evaluateHealthySidecarForReuse(
        minimumNodeMajorVersion: Int,
        localRuntimeScriptURL: URL
    ) -> SidecarHealthyReuseDecision {
        _ = minimumNodeMajorVersion
        _ = localRuntimeScriptURL
        return reuseDecision
    }

    func terminateStaleSidecarProcesses(matching scriptPath: String) {
        terminateCalls.append(scriptPath)
    }
}

private final class FakeProcessController: SidecarProcessControlling {
    var isRunning = false
    var staleHandle = false
    private(set) var clearStaleCalls = 0
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private var terminationHandler: ((SidecarProcessTermination) -> Void)?

    func hasStaleProcessHandle() -> Bool {
        staleHandle
    }

    func clearStaleProcessHandle() {
        clearStaleCalls += 1
        staleHandle = false
    }

    func start(
        nodeExecutable: URL,
        scriptURL: URL,
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (SidecarProcessTermination) -> Void
    ) throws {
        _ = nodeExecutable
        _ = scriptURL
        _ = outputHandler
        startCalls += 1
        isRunning = true
        self.terminationHandler = terminationHandler
    }

    func stop() {
        stopCalls += 1
        isRunning = false
    }

    func emitTermination(intentional: Bool, status: Int32) {
        isRunning = false
        terminationHandler?(
            SidecarProcessTermination(
                reasonRawValue: 1,
                status: status,
                processIdentifier: 101,
                intentional: intentional
            )
        )
    }
}

private final class FakeRestartPolicy: SidecarRestartPolicyManaging {
    var retryAttempt: Int = 0
    private var canAttemptResults: [Bool]
    private let nextDelay: TimeInterval
    private(set) var canAttemptCallCount = 0
    private(set) var resetCalls = 0

    init(canAttemptResults: [Bool], nextDelay: TimeInterval = 1.5) {
        self.canAttemptResults = canAttemptResults
        self.nextDelay = nextDelay
    }

    func canAttemptRestart(now: Date) -> Bool {
        _ = now
        canAttemptCallCount += 1
        if canAttemptResults.isEmpty {
            return true
        }
        return canAttemptResults.removeFirst()
    }

    func resetRetryAttempt() {
        resetCalls += 1
        retryAttempt = 0
    }

    func nextRetryDelay() -> TimeInterval {
        retryAttempt += 1
        return nextDelay
    }
}
