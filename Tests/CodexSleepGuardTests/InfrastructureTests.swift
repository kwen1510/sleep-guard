import XCTest
@testable import CodexSleepGuardCore

final class InfrastructureTests: XCTestCase {
    func testSystemPathsBuildExpectedLocations() {
        let root = URL(fileURLWithPath: "/tmp/codex-home")
        let paths = CodexSystemPaths(codexHome: root)

        XCTAssertEqual(paths.sessionsDirectory.path, "/tmp/codex-home/sessions")
        XCTAssertEqual(paths.processManagerFile.path, "/tmp/codex-home/process_manager/chat_processes.json")
    }

    func testFileSystemSessionProviderFindsRecentJsonlFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let sessions = root.appendingPathComponent("sessions/2026/06/01", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let recent = sessions.appendingPathComponent("recent.jsonl")
        let old = sessions.appendingPathComponent("old.jsonl")
        let ignored = sessions.appendingPathComponent("ignored.txt")
        try "recent".write(to: recent, atomically: true, encoding: .utf8)
        try "old".write(to: old, atomically: true, encoding: .utf8)
        try "ignored".write(to: ignored, atomically: true, encoding: .utf8)

        let now = Date(timeIntervalSince1970: 10_000)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: recent.path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-10_000)], ofItemAtPath: old.path)

        let provider = FileSystemSessionFileProvider(sessionsDirectory: root.appendingPathComponent("sessions"), lookback: 60)

        let files = try provider.recentSessionFiles(now: now)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.lastPathComponent, recent.lastPathComponent)
    }

    func testFileSystemSessionProviderReturnsRecentTailLines() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("tail.jsonl")
        let text = (0..<40).map { "line-\($0)" }.joined(separator: "\n")
        try text.write(to: file, atomically: true, encoding: .utf8)

        let provider = FileSystemSessionFileProvider(sessionsDirectory: root)
        let lines = try provider.recentLines(from: file, maxBytes: 35)

        XCTAssertTrue(lines.last == "line-39")
        XCTAssertFalse(lines.contains("line-0"))
    }

    func testSystemProcessProviderListsCurrentProcesses() throws {
        let processes = try SystemProcessProvider().runningProcesses()

        XCTAssertFalse(processes.isEmpty)
        XCTAssertTrue(processes.contains { $0.searchableText.contains("xctest") || $0.searchableText.contains("xcodebuild") })
    }

    func testShellCommandRunnerCapturesOutput() async throws {
        let output = try await ShellCommandRunner().run(
            executable: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello"]
        )

        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testRealSleepManagerCreatesAndReleasesAssertion() throws {
        let manager = SleepManager()

        try manager.enableProtection(reason: "Codex Sleep Guard XCTest")
        XCTAssertTrue(manager.isProtectionEnabled)

        manager.disableProtection()
        XCTAssertFalse(manager.isProtectionEnabled)
    }

    func testSleepManagerErrorDescription() {
        let error = SleepManagerError.assertionCreateFailed(kIOReturnError)

        XCTAssertTrue(error.localizedDescription.contains("IOPMAssertionCreateWithName failed"))
    }

    func testMockSleepManagerSurfacesEnableError() {
        let manager = MockSleepManager()
        manager.enableError = TestError.expected

        XCTAssertThrowsError(try manager.enableProtection(reason: "test"))
        XCTAssertFalse(manager.isProtectionEnabled)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
