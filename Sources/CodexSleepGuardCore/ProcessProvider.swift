import Foundation

public struct RunningProcess: Equatable {
    public var pid: Int32
    public var command: String
    public var arguments: String

    public init(pid: Int32, command: String, arguments: String) {
        self.pid = pid
        self.command = command
        self.arguments = arguments
    }

    public var searchableText: String {
        "\(command) \(arguments)"
    }
}

public protocol ProcessProviding {
    func runningProcesses() throws -> [RunningProcess]
}

public final class SystemProcessProvider: ProcessProviding {
    public init() {}

    public func runningProcesses() throws -> [RunningProcess] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["ax", "-o", "pid=,comm=,args="]
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = Int32(parts[0]) else { return nil }
            let command = String(parts[1])
            let arguments = parts.count > 2 ? String(parts[2]) : ""
            return RunningProcess(pid: pid, command: command, arguments: arguments)
        }
    }
}

public final class CodexProcessDetector: CodexActivityDetecting {
    public let strategyName = "Codex process presence"
    private let processProvider: ProcessProviding

    public init(processProvider: ProcessProviding = SystemProcessProvider()) {
        self.processProvider = processProvider
    }

    public func snapshot(now: Date) async -> CodexActivitySnapshot {
        do {
            let processes = try processProvider.runningProcesses()
            let detected = processes.contains { process in
                let text = process.searchableText.lowercased()
                return text.contains("/applications/codex.app")
                    || text.contains("codex app-server")
                    || text.contains("openai.chatgpt")
            }

            return .idle(
                detected: detected,
                strategy: strategyName,
                detail: detected ? "Codex process is running. Process presence is not treated as active work." : "No Codex process found.",
                observedAt: now
            )
        } catch {
            return .idle(
                strategy: strategyName,
                detail: "Unable to inspect process list: \(error.localizedDescription)",
                observedAt: now
            )
        }
    }
}
