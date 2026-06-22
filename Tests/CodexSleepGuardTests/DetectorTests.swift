import XCTest
@testable import CodexSleepGuardCore

final class DetectorTests: XCTestCase {
    func testSessionDetectorMarksCodexActiveFromToolCall() async {
        let now = Date(timeIntervalSince1970: 1_800)
        let provider = MockSessionFileProvider(lines: [
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_780), type: "response_item", payload: [
                "type": "function_call",
                "name": "exec_command"
            ])
        ])
        let detector = SessionFileActivityDetector(provider: provider)

        let snapshot = await detector.snapshot(now: now)

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .active)
        XCTAssertEqual(snapshot.detectionStrategy, "Codex session JSONL")
    }

    func testSessionDetectorMarksCodexIdleAfterFinalResponse() async {
        let now = Date(timeIntervalSince1970: 1_800)
        let provider = MockSessionFileProvider(lines: [
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_780), type: "response_item", payload: [
                "type": "function_call",
                "name": "exec_command"
            ]),
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_790), type: "response_item", payload: [
                "type": "message",
                "role": "assistant",
                "phase": "final"
            ])
        ])
        let detector = SessionFileActivityDetector(provider: provider)

        let snapshot = await detector.snapshot(now: now)

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testSessionDetectorIgnoresStaleActiveSignal() async {
        let now = Date(timeIntervalSince1970: 2_800)
        let provider = MockSessionFileProvider(lines: [
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_000), type: "response_item", payload: [
                "type": "reasoning"
            ])
        ])
        let detector = SessionFileActivityDetector(provider: provider, activeStalenessInterval: 60)

        let snapshot = await detector.snapshot(now: now)

        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCodexDetectedFromProcessList() async {
        let detector = CodexProcessDetector(processProvider: MockProcessProvider(processes: [
            RunningProcess(pid: 10, command: "/Applications/Codex.app/Contents/MacOS/Codex", arguments: "")
        ]))

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCodexNotDetectedFromProcessList() async {
        let detector = CodexProcessDetector(processProvider: MockProcessProvider(processes: [
            RunningProcess(pid: 10, command: "/Applications/TextEdit.app/Contents/MacOS/TextEdit", arguments: "")
        ]))

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testManagedProcessDetectorMarksNonPersistentCommandActive() async throws {
        let entry = ManagedCodexProcess(
            command: "xcodebuild test",
            osPid: 42,
            startedAtMs: 1_000_000
        )
        let data = try JSONEncoder().encode([entry])
        let detector = ManagedProcessActivityDetector(
            provider: MockManagedProcessFileProvider(data: data),
            processProvider: MockProcessProvider(processes: [
                RunningProcess(pid: 42, command: "/usr/bin/xcodebuild", arguments: "test")
            ])
        )

        let snapshot = await detector.snapshot(now: Date(timeIntervalSince1970: 1_001))

        XCTAssertEqual(snapshot.workState, .active)
    }

    func testManagedProcessDetectorIgnoresDevServerFalsePositive() async throws {
        let entry = ManagedCodexProcess(
            command: "npm run dev",
            osPid: 42,
            startedAtMs: 1_000_000
        )
        let data = try JSONEncoder().encode([entry])
        let detector = ManagedProcessActivityDetector(
            provider: MockManagedProcessFileProvider(data: data),
            processProvider: MockProcessProvider(processes: [
                RunningProcess(pid: 42, command: "node", arguments: "vite")
            ])
        )

        let snapshot = await detector.snapshot(now: Date(timeIntervalSince1970: 1_001))

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCompositeDetectorPrefersActiveStrategy() async {
        let detector = CompositeCodexActivityDetector(detectors: [
            StaticCodexActivityDetector(snapshot: .idle(detected: true, strategy: "process", detail: "open")),
            StaticCodexActivityDetector(snapshot: .active(strategy: "session", detail: "working"))
        ])

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .active)
        XCTAssertEqual(snapshot.detectionStrategy, "session")
    }
}
