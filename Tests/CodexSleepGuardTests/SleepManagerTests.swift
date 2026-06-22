import XCTest
@testable import CodexSleepGuardCore

final class SleepManagerTests: XCTestCase {
    func testMockAssertionCreated() throws {
        let manager = MockSleepManager()

        try manager.enableProtection(reason: "test")

        XCTAssertTrue(manager.isProtectionEnabled)
        XCTAssertEqual(manager.enableCount, 1)
    }

    func testMockAssertionReleased() throws {
        let manager = MockSleepManager()

        try manager.enableProtection(reason: "test")
        manager.disableProtection()

        XCTAssertFalse(manager.isProtectionEnabled)
        XCTAssertEqual(manager.disableCount, 1)
    }

    func testMockAssertionCreateIsIdempotent() throws {
        let manager = MockSleepManager()

        try manager.enableProtection(reason: "test")
        try manager.enableProtection(reason: "test")

        XCTAssertEqual(manager.enableCount, 1)
    }
}
