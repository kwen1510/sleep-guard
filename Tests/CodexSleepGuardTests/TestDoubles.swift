import Foundation
@testable import CodexSleepGuardCore

final class QueueDetector: CodexActivityDetecting {
    let strategyName = "Queue"
    private var snapshots: [CodexActivitySnapshot]

    init(_ snapshots: [CodexActivitySnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot(now: Date) async -> CodexActivitySnapshot {
        guard !snapshots.isEmpty else {
            return .idle(strategy: strategyName, detail: "empty", observedAt: now)
        }

        var next = snapshots.removeFirst()
        next.observedAt = now
        return next
    }
}

final class MockProcessProvider: ProcessProviding {
    let processes: [RunningProcess]

    init(processes: [RunningProcess]) {
        self.processes = processes
    }

    func runningProcesses() throws -> [RunningProcess] {
        processes
    }
}

final class MockManagedProcessFileProvider: ManagedProcessFileProviding {
    let storedData: Data

    init(data: Data) {
        self.storedData = data
    }

    func data() throws -> Data {
        storedData
    }
}

final class MockSessionFileProvider: SessionFileProviding {
    let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    func recentSessionFiles(now: Date) throws -> [URL] {
        [URL(fileURLWithPath: "/tmp/mock.jsonl")]
    }

    func recentLines(from file: URL, maxBytes: Int) throws -> [String] {
        lines
    }
}

enum TestError: Error {
    case expected
}

final class ThrowingSessionFileProvider: SessionFileProviding {
    func recentSessionFiles(now: Date) throws -> [URL] {
        throw TestError.expected
    }

    func recentLines(from file: URL, maxBytes: Int) throws -> [String] {
        throw TestError.expected
    }
}

final class EmptySessionFileProvider: SessionFileProviding {
    func recentSessionFiles(now: Date) throws -> [URL] {
        []
    }

    func recentLines(from file: URL, maxBytes: Int) throws -> [String] {
        []
    }
}

final class ThrowingManagedProcessFileProvider: ManagedProcessFileProviding {
    func data() throws -> Data {
        throw TestError.expected
    }
}

final class ThrowingProcessProvider: ProcessProviding {
    func runningProcesses() throws -> [RunningProcess] {
        throw TestError.expected
    }
}

final class MockCommandRunner: CommandRunning {
    var result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func run(executable: URL, arguments: [String]) async throws -> String {
        try result.get()
    }
}

func jsonLine(timestamp: Date, type: String, payload: [String: Any]) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let object: [String: Any] = [
        "timestamp": formatter.string(from: timestamp),
        "type": type,
        "payload": payload
    ]
    let data = try! JSONSerialization.data(withJSONObject: object)
    return String(data: data, encoding: .utf8)!
}
