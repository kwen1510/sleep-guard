import XCTest
@testable import CodexSleepGuardCore

final class DiagnosticsManagerTests: XCTestCase {
    func testParsesAssertionOwners() {
        let output = """
        Assertion status system-wide:
           PreventUserIdleSystemSleep    1
        Listed by owning process:
           pid 123(Codex Sleep Guard): [0x000001] 00:00:10 PreventUserIdleSystemSleep named: "Codex is active"
        """

        let owners = DiagnosticsManager.parseAssertionOwners(from: output)

        XCTAssertEqual(owners.count, 2)
        XCTAssertTrue(owners.last?.contains("Codex Sleep Guard") == true)
    }
}
