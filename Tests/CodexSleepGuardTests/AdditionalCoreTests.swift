import XCTest
@testable import CodexSleepGuardCore

final class AdditionalCoreTests: XCTestCase {
    func testDetectorDefaultSnapshotConvenienceUsesCurrentDate() async {
        let detector = StaticCodexActivityDetector(snapshot: .active(strategy: "static", detail: "working"))

        let snapshot = await detector.snapshot()

        XCTAssertEqual(snapshot.workState, .active)
        XCTAssertTrue(snapshot.workState.isActive)
    }

    func testSessionDetectorHandlesNoSessionFiles() async {
        let detector = SessionFileActivityDetector(provider: EmptySessionFileProvider())

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testSessionDetectorHandlesReadError() async {
        let detector = SessionFileActivityDetector(provider: ThrowingSessionFileProvider())

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
        XCTAssertTrue(snapshot.detail.contains("Unable to read"))
    }

    func testSessionDetectorTreatsAgentMessageFinalAsIdleBoundary() async {
        let now = Date(timeIntervalSince1970: 1_800)
        let provider = MockSessionFileProvider(lines: [
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_780), type: "event_msg", payload: [
                "type": "agent_message",
                "phase": "commentary"
            ]),
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_790), type: "event_msg", payload: [
                "type": "agent_message",
                "phase": "final"
            ])
        ])
        let detector = SessionFileActivityDetector(provider: provider)

        let snapshot = await detector.snapshot(now: now)

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testSessionDetectorTreatsTelemetryAsActive() async {
        let now = Date(timeIntervalSince1970: 1_800)
        let provider = MockSessionFileProvider(lines: [
            jsonLine(timestamp: Date(timeIntervalSince1970: 1_790), type: "event_msg", payload: [
                "type": "thread_goal_updated"
            ])
        ])
        let detector = SessionFileActivityDetector(provider: provider)

        let snapshot = await detector.snapshot(now: now)

        XCTAssertEqual(snapshot.workState, .active)
    }

    func testSessionDetectorHandlesInvalidSessionLinesAsDetectedIdle() async {
        let detector = SessionFileActivityDetector(provider: MockSessionFileProvider(lines: ["not json"]))

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testManagedProcessDetectorHandlesNoEntries() async throws {
        let data = try JSONEncoder().encode([ManagedCodexProcess]())
        let detector = ManagedProcessActivityDetector(
            provider: MockManagedProcessFileProvider(data: data),
            processProvider: MockProcessProvider(processes: [])
        )

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testManagedProcessDetectorHandlesHistoryWithoutRunningPid() async throws {
        let data = try JSONEncoder().encode([
            ManagedCodexProcess(command: "xcodebuild test", osPid: 123, startedAtMs: 1_000)
        ])
        let detector = ManagedProcessActivityDetector(
            provider: MockManagedProcessFileProvider(data: data),
            processProvider: MockProcessProvider(processes: [])
        )

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testManagedProcessDetectorIgnoresVeryOldRunningCommand() async throws {
        let data = try JSONEncoder().encode([
            ManagedCodexProcess(command: "xcodebuild test", osPid: 123, startedAtMs: 1_000)
        ])
        let detector = ManagedProcessActivityDetector(
            provider: MockManagedProcessFileProvider(data: data),
            processProvider: MockProcessProvider(processes: [
                RunningProcess(pid: 123, command: "xcodebuild", arguments: "test")
            ]),
            maximumRunningCommandAge: 10
        )

        let snapshot = await detector.snapshot(now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testManagedProcessDetectorHandlesProviderError() async {
        let detector = ManagedProcessActivityDetector(
            provider: ThrowingManagedProcessFileProvider(),
            processProvider: MockProcessProvider(processes: [])
        )

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCodexProcessDetectorHandlesProviderError() async {
        let detector = CodexProcessDetector(processProvider: ThrowingProcessProvider())

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCompositeDetectorHandlesNoDetectors() async {
        let detector = CompositeCodexActivityDetector(detectors: [])

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertFalse(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
    }

    func testCompositeDetectorMergesIdleDetectionDetails() async {
        let detector = CompositeCodexActivityDetector(detectors: [
            StaticCodexActivityDetector(snapshot: .idle(detected: true, strategy: "process", detail: "open")),
            StaticCodexActivityDetector(snapshot: .idle(detected: false, strategy: "session", detail: "idle"))
        ])

        let snapshot = await detector.snapshot(now: Date())

        XCTAssertTrue(snapshot.codexDetected)
        XCTAssertEqual(snapshot.workState, .idle)
        XCTAssertTrue(snapshot.detail.contains("process: open"))
    }
}

@MainActor
final class AdditionalMainActorTests: XCTestCase {
    func testDiagnosticsRefreshSuccessAndFailure() async {
        let success = DiagnosticsManager(commandRunner: MockCommandRunner(result: .success("""
        Assertion status system-wide:
           PreventUserIdleSystemSleep    1
           pid 456(Codex Sleep Guard): [0x0001] PreventUserIdleSystemSleep
        """)))

        await success.refresh()

        XCTAssertNil(success.lastError)
        XCTAssertEqual(success.activeAssertions.count, 2)
        XCTAssertFalse(success.rawAssertions.isEmpty)

        let failure = DiagnosticsManager(commandRunner: MockCommandRunner(result: .failure(TestError.expected)))
        await failure.refresh()

        XCTAssertNotNil(failure.lastError)
        XCTAssertTrue(failure.rawAssertions.isEmpty)
        XCTAssertTrue(failure.activeAssertions.isEmpty)
    }

    func testAppStateMonitoringLoopCanStartAndStop() async throws {
        let detector = QueueDetector([
            .active(strategy: "queue", detail: "active"),
            .idle(detected: true, strategy: "queue", detail: "idle")
        ])
        let sleep = MockSleepManager()
        let state = AppState(
            detector: detector,
            sleepManager: sleep,
            gracePeriod: GracePeriodManager(duration: 300),
            refreshInterval: 0.01
        )

        state.startMonitoring()
        try await Task.sleep(nanoseconds: 50_000_000)
        state.stopMonitoring()

        XCTAssertTrue(sleep.enableCount >= 1)
    }

    func testDefaultAppStateInitializes() {
        let state = AppState()

        XCTAssertEqual(state.statusText, "Idle")
        XCTAssertEqual(state.currentDetectionStrategy, "Not checked yet")
    }
}
