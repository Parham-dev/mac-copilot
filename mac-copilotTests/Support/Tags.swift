import Testing

// MARK: - Shared Swift Testing Tag Declarations
//
// Usage: annotate each @Test with one or more tags, e.g.
//   @Test(.tags(.unit)) func myTest() { … }
//   @Test(.tags(.integration, .async)) func myAsyncTest() { … }
//
// Tag semantics
// ─────────────
// .unit        Pure logic tests. No I/O, no system dependencies.
//              Fast, deterministic, and isolated by construction.
//
// .integration Tests that exercise real infrastructure: SwiftData,
//              UserDefaults, the file system, real URL sessions, etc.
//
// .smoke       Sanity-check tests that verify fixtures, container
//              wiring, and shared test-support code are healthy before
//              the full suite runs. Should be a tiny set and very fast.
//
// .regression  Guards against a specific previously-fixed bug.
//              Add a short comment next to the @Test explaining the
//              original defect that is being prevented from recurring.
//
// .async_      Tests that exercise concurrency-sensitive behaviour:
//              ordering guarantees, stale-operation cancellation, race
//              detection, actor isolation, etc.

extension Tag {
    /// Pure logic, no I/O or system dependencies.
    @Tag static var unit: Self

    /// Touches real infrastructure (SwiftData, UserDefaults, filesystem, …).
    @Tag static var integration: Self

    /// Fixture / container wiring sanity checks.
    @Tag static var smoke: Self

    /// Guards a specific previously-fixed regression.
    @Tag static var regression: Self

    /// Concurrency-sensitive behaviour under test.
    @Tag static var async_: Self
}
