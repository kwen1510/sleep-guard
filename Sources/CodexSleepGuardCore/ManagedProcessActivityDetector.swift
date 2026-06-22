import Foundation

public protocol ManagedProcessFileProviding {
    func data() throws -> Data
}

public final class FileManagedProcessProvider: ManagedProcessFileProviding {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func data() throws -> Data {
        try Data(contentsOf: url)
    }
}

public struct ManagedCodexProcess: Codable, Equatable {
    public var command: String
    public var conversationId: String?
    public var osPid: Int32?
    public var processId: String?
    public var startedAtMs: Int?
    public var updatedAtMs: Int?

    public init(
        command: String,
        conversationId: String? = nil,
        osPid: Int32? = nil,
        processId: String? = nil,
        startedAtMs: Int? = nil,
        updatedAtMs: Int? = nil
    ) {
        self.command = command
        self.conversationId = conversationId
        self.osPid = osPid
        self.processId = processId
        self.startedAtMs = startedAtMs
        self.updatedAtMs = updatedAtMs
    }
}

public final class ManagedProcessActivityDetector: CodexActivityDetecting {
    public let strategyName = "Codex managed process"

    private let provider: ManagedProcessFileProviding
    private let processProvider: ProcessProviding
    private let maximumRunningCommandAge: TimeInterval

    public init(
        provider: ManagedProcessFileProviding,
        processProvider: ProcessProviding = SystemProcessProvider(),
        maximumRunningCommandAge: TimeInterval = 6 * 60 * 60
    ) {
        self.provider = provider
        self.processProvider = processProvider
        self.maximumRunningCommandAge = maximumRunningCommandAge
    }

    public convenience init(paths: CodexSystemPaths = CodexSystemPaths(), processProvider: ProcessProviding = SystemProcessProvider()) {
        self.init(provider: FileManagedProcessProvider(url: paths.processManagerFile), processProvider: processProvider)
    }

    public func snapshot(now: Date) async -> CodexActivitySnapshot {
        do {
            let entries = try JSONDecoder().decode([ManagedCodexProcess].self, from: try provider.data())
            let runningPIDs = Set(try processProvider.runningProcesses().map(\.pid))
            let runningEntries = entries.filter { entry in
                guard let pid = entry.osPid else { return false }
                return runningPIDs.contains(pid)
            }

            guard !runningEntries.isEmpty else {
                return .idle(
                    detected: !entries.isEmpty,
                    strategy: strategyName,
                    detail: entries.isEmpty ? "No Codex-managed commands found." : "Codex-managed command history exists, but no tracked command is running.",
                    observedAt: now
                )
            }

            if let activeEntry = runningEntries.first(where: { isActiveWork($0, now: now) }) {
                return .active(
                    strategy: strategyName,
                    detail: "Codex-managed command is still running: \(activeEntry.command)",
                    observedAt: now
                )
            }

            return .idle(
                detected: true,
                strategy: strategyName,
                detail: "Only ignored persistent commands are running.",
                observedAt: now
            )
        } catch {
            return .idle(
                strategy: strategyName,
                detail: "Unable to inspect Codex process manager file: \(error.localizedDescription)",
                observedAt: now
            )
        }
    }

    private func isActiveWork(_ entry: ManagedCodexProcess, now: Date) -> Bool {
        guard !isKnownPersistentCommand(entry.command) else { return false }
        guard let startedAtMs = entry.startedAtMs else { return true }
        let startedAt = Date(timeIntervalSince1970: TimeInterval(startedAtMs) / 1000)
        return now.timeIntervalSince(startedAt) <= maximumRunningCommandAge
    }

    private func isKnownPersistentCommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        let persistentPatterns = [
            "npm run dev",
            "pnpm dev",
            "yarn dev",
            "bun run dev",
            "vite",
            "next dev",
            "docker compose up",
            "docker-compose up",
            "docker run",
            "supabase start",
            "postgres",
            "mysqld",
            "mysql.server",
            "redis-server"
        ]

        return persistentPatterns.contains { normalized.contains($0) }
    }
}
