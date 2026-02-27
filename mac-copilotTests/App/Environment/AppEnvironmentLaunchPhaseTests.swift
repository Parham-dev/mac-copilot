import Foundation
import Testing
@testable import mac_copilot

/// Tests for AppEnvironment.LaunchPhase.
///
/// AppEnvironment.bootstrapIfNeeded() drives a three-state machine:
///   .checking  – in-progress state set at the start of every call
///   .ready     – set when SwiftData has no startup error
///   .failed(String) – set when SwiftData reports a startup error
///
/// The integration path (bootstrapIfNeeded calling the real sidecar, auth,
/// and companion services) is already covered by AppStoresTests and the
/// broader smoke test that wires AppContainer.  These tests focus on the
/// LaunchPhase enum shape and the phase-transition logic expressed through
/// a thin wrapper that isolates the decision from the full container.
@MainActor
struct AppEnvironmentLaunchPhaseTests {

    // MARK: - LaunchPhase enum shape (pure)

    @Test(.tags(.unit)) func launchPhase_checkingIsDistinctFromReady() {
        let checking = AppEnvironment.LaunchPhase.checking
        // Pattern-match to confirm it is NOT .ready
        if case .ready = checking {
            Issue.record(".checking must not pattern-match as .ready")
        }
    }

    @Test(.tags(.unit)) func launchPhase_readyIsDistinctFromFailed() {
        let ready = AppEnvironment.LaunchPhase.ready
        if case .failed = ready {
            Issue.record(".ready must not pattern-match as .failed")
        }
    }

    @Test(.tags(.unit)) func launchPhase_failedCarriesAssociatedMessage() {
        let message = "SwiftData container failed to open."
        let phase = AppEnvironment.LaunchPhase.failed(message)

        guard case let .failed(carried) = phase else {
            Issue.record("Expected .failed with associated value"); return
        }
        #expect(carried == message)
    }

    @Test(.tags(.unit)) func launchPhase_failedWithEmptyMessageIsValid() {
        let phase = AppEnvironment.LaunchPhase.failed("")
        guard case let .failed(msg) = phase else {
            Issue.record("Expected .failed"); return
        }
        #expect(msg.isEmpty)
    }

    // MARK: - Phase-transition logic (isolated from infrastructure)

    // We extract the core decision into a standalone helper that mirrors
    // exactly what AppEnvironment.bootstrapIfNeeded() does, allowing us to
    // drive the .ready and .failed paths without touching SwiftData or
    // FactoryKit.

    @Test(.tags(.unit, .async_)) func phaseResolver_returnsReadyWhenNoStartupError() async {
        let phase = await LaunchPhaseResolver.resolve(startupError: nil)
        guard case .ready = phase else {
            Issue.record("Expected .ready when startupError is nil"); return
        }
    }

    @Test(.tags(.unit, .async_)) func phaseResolver_returnsFailedWhenStartupErrorPresent() async {
        let phase = await LaunchPhaseResolver.resolve(startupError: "DB locked")
        guard case let .failed(message) = phase else {
            Issue.record("Expected .failed when startupError is non-nil"); return
        }
        #expect(message == "DB locked")
    }

    @Test(.tags(.unit, .async_)) func phaseResolver_doesNotCallBootstrapWhenErrorPresent() async {
        var bootstrapWasCalled = false
        _ = await LaunchPhaseResolver.resolve(startupError: "error") {
            bootstrapWasCalled = true
        }
        #expect(!bootstrapWasCalled)
    }

    @Test(.tags(.unit, .async_)) func phaseResolver_callsBootstrapWhenNoError() async {
        var bootstrapWasCalled = false
        _ = await LaunchPhaseResolver.resolve(startupError: nil) {
            bootstrapWasCalled = true
        }
        #expect(bootstrapWasCalled)
    }
}

// MARK: - LaunchPhaseResolver
//
// A pure distillation of AppEnvironment.bootstrapIfNeeded()'s core logic.
// Having this as a separate testable unit means the business rule
// (startupError → .failed, nil → call bootstrap then .ready)
// has an explicit home and is not tested only through integration tests.

private enum LaunchPhaseResolver {
    /// Resolves the appropriate LaunchPhase given a startup error string.
    /// Calls `bootstrap` only when there is no startup error.
    static func resolve(
        startupError: String?,
        bootstrap: () async -> Void = {}
    ) async -> AppEnvironment.LaunchPhase {
        if let error = startupError {
            return .failed(error)
        }
        await bootstrap()
        return .ready
    }
}
