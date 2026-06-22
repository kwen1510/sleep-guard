import XCTest
@testable import CodexSleepGuardCore

final class GracePeriodManagerTests: XCTestCase {
    func testGraceTimerStarts() {
        let manager = GracePeriodManager(duration: 300)

        manager.start()

        XCTAssertEqual(manager.remainingSeconds, 300)
        XCTAssertTrue(manager.isRunning)
    }

    func testGraceTimerCancels() {
        let manager = GracePeriodManager(duration: 300)

        manager.start()
        manager.cancel()

        XCTAssertEqual(manager.remainingSeconds, 0)
        XCTAssertFalse(manager.isRunning)
    }

    func testGraceTimerCompletes() {
        let manager = GracePeriodManager(duration: 300)

        manager.start()
        manager.tick(by: 120)
        manager.tick(by: 180)

        XCTAssertEqual(manager.remainingSeconds, 0)
        XCTAssertFalse(manager.isRunning)
    }
}
