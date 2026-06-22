import XCTest
@testable import CodexSleepGuardCore

@MainActor
final class IntegrationTests: XCTestCase {
    func testCodexActiveIdleCompletionGraceAssertionLifecycle() async {
        let detector = QueueDetector([
            .active(strategy: "session", detail: "tool call"),
            .idle(detected: true, strategy: "session", detail: "final response"),
            .idle(detected: true, strategy: "session", detail: "still idle")
        ])
        let sleep = MockSleepManager()
        let grace = GracePeriodManager(duration: 300)
        let state = AppState(detector: detector, sleepManager: sleep, gracePeriod: grace)

        await state.refresh(now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(state.sleepProtectionEnabled)

        await state.refresh(now: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(state.remainingGracePeriod, 300)
        XCTAssertTrue(state.sleepProtectionEnabled)

        state.advanceGrace(by: 300, now: Date(timeIntervalSince1970: 301))
        XCTAssertFalse(state.sleepProtectionEnabled)

        await state.refresh(now: Date(timeIntervalSince1970: 302))
        XCTAssertFalse(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(sleep.disableCount, 1)
    }

    func testConsecutiveTasksDuringGraceRemainProtected() async {
        let detector = QueueDetector([
            .active(strategy: "session", detail: "task 1"),
            .idle(detected: true, strategy: "session", detail: "task 1 done"),
            .active(strategy: "session", detail: "task 2"),
            .idle(detected: true, strategy: "session", detail: "task 2 done")
        ])
        let sleep = MockSleepManager()
        let state = AppState(detector: detector, sleepManager: sleep, gracePeriod: GracePeriodManager(duration: 300))

        await state.refresh(now: Date(timeIntervalSince1970: 0))
        await state.refresh(now: Date(timeIntervalSince1970: 10))
        state.advanceGrace(by: 120, now: Date(timeIntervalSince1970: 130))
        await state.refresh(now: Date(timeIntervalSince1970: 131))
        await state.refresh(now: Date(timeIntervalSince1970: 132))

        XCTAssertTrue(state.sleepProtectionEnabled)
        XCTAssertEqual(sleep.enableCount, 1)
        XCTAssertEqual(state.remainingGracePeriod, 300)
    }
}
