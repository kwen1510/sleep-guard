import XCTest
@testable import CodexSleepGuardCore

@MainActor
final class AppStateTests: XCTestCase {
    func testCodexActiveEnablesAssertion() {
        let detector = QueueDetector([
            .active(strategy: "test", detail: "active")
        ])
        let sleep = MockSleepManager()
        let state = AppState(detector: detector, sleepManager: sleep, gracePeriod: GracePeriodManager(duration: 300))

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(state.codexDetected)
        XCTAssertEqual(state.codexActivity, .active)
        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(state.statusText, "Protected")
    }

    func testCodexIdleDoesNotEnableAssertion() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "idle"), now: Date())

        XCTAssertTrue(state.codexDetected)
        XCTAssertEqual(state.codexActivity, .idle)
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 0)
    }

    func testActiveToIdleStartsGracePeriodAndKeepsAssertion() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "finished"), now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(state.codexActivity, .idle)
        XCTAssertEqual(state.remainingGracePeriod, 300)
        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
    }

    func testGraceTimerCompletesAndReleasesAssertion() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "done"), now: Date(timeIntervalSince1970: 1))
        state.advanceGrace(by: 299, now: Date(timeIntervalSince1970: 300))
        XCTAssertTrue(state.sleepProtectionEnabled)

        state.advanceGrace(by: 1, now: Date(timeIntervalSince1970: 301))

        XCTAssertEqual(state.remainingGracePeriod, 0)
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.disableCount, 1)
        XCTAssertEqual(state.statusText, "Idle")
    }

    func testGraceTimerCancelledWhenNewTaskStarts() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "test", detail: "first"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "done"), now: Date(timeIntervalSince1970: 10))
        state.advanceGrace(by: 120, now: Date(timeIntervalSince1970: 130))
        state.apply(snapshot: .active(strategy: "test", detail: "second"), now: Date(timeIntervalSince1970: 131))

        XCTAssertEqual(state.remainingGracePeriod, 0)
        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
    }

    func testMultipleRapidTransitionsUseSingleAssertion() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active 1"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "idle"), now: Date(timeIntervalSince1970: 1))
        state.apply(snapshot: .active(strategy: "test", detail: "active 2"), now: Date(timeIntervalSince1970: 2))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "idle"), now: Date(timeIntervalSince1970: 3))

        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(sleep.disableCount, 0)
    }

    func testFalsePositivePreventionForDetectedButIdleCodex() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .idle(detected: true, strategy: "process", detail: "Codex open"), now: Date())

        XCTAssertTrue(state.codexDetected)
        XCTAssertEqual(state.codexActivity, .idle)
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 0)
    }

    func testLongRunningActiveSessionKeepsProtectionEnabled() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        for minute in 0..<120 {
            state.apply(
                snapshot: .active(strategy: "session", detail: "active"),
                now: Date(timeIntervalSince1970: TimeInterval(minute * 60))
            )
        }

        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(sleep.disableCount, 0)
    }

    func testCodexExitUnexpectedlyStartsGraceThenReleases() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "session", detail: "active"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: false, strategy: "session", detail: "missing"), now: Date(timeIntervalSince1970: 1))

        XCTAssertFalse(state.codexDetected)
        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(state.remainingGracePeriod, 300)

        state.advanceGrace(by: 300, now: Date(timeIntervalSince1970: 301))

        XCTAssertFalse(state.sleepProtectionEnabled)
    }

    func testGuardSwitchOffPreventsAssertionWhenCodexActive() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300),
            guardEnabled: false
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))

        XCTAssertFalse(state.guardEnabled)
        XCTAssertTrue(state.codexDetected)
        XCTAssertEqual(state.codexActivity, .active)
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 0)
        XCTAssertEqual(state.statusText, "Off")
    }

    func testTurningGuardOffReleasesAssertionAndCancelsGrace() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300)
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))
        state.apply(snapshot: .idle(detected: true, strategy: "test", detail: "done"), now: Date(timeIntervalSince1970: 1))

        state.setGuardEnabled(false, now: Date(timeIntervalSince1970: 2))

        XCTAssertFalse(state.guardEnabled)
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(state.remainingGracePeriod, 0)
        XCTAssertEqual(sleep.disableCount, 1)
        XCTAssertEqual(state.statusText, "Off")
    }

    func testTurningGuardOnReconcilesCurrentActiveSnapshot() {
        let sleep = MockSleepManager()
        let state = AppState(
            detector: QueueDetector([]),
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300),
            guardEnabled: false
        )

        state.apply(snapshot: .active(strategy: "test", detail: "active"), now: Date(timeIntervalSince1970: 0))
        state.setGuardEnabled(true, now: Date(timeIntervalSince1970: 1))

        XCTAssertTrue(state.guardEnabled)
        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(state.statusText, "Protected")
    }

    func testGuardSwitchPersistsInUserDefaults() throws {
        let suiteName = "CodexSleepGuardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstState = AppState(
            detector: QueueDetector([]),
            sleepManager: MockSleepManager(),
            userDefaults: defaults
        )
        firstState.setGuardEnabled(false)

        let secondState = AppState(
            detector: QueueDetector([]),
            sleepManager: MockSleepManager(),
            userDefaults: defaults
        )

        XCTAssertFalse(secondState.guardEnabled)
        XCTAssertEqual(secondState.statusText, "Off")
    }
}
