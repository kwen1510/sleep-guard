import Foundation

public protocol SessionFileProviding {
    func recentSessionFiles(now: Date) throws -> [URL]
    func recentLines(from file: URL, maxBytes: Int) throws -> [String]
}

public final class FileSystemSessionFileProvider: SessionFileProviding {
    private let sessionsDirectory: URL
    private let fileManager: FileManager
    private let lookback: TimeInterval
    private let maxFiles: Int

    public init(
        sessionsDirectory: URL,
        fileManager: FileManager = .default,
        lookback: TimeInterval = 14 * 24 * 60 * 60,
        maxFiles: Int = 30
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.fileManager = fileManager
        self.lookback = lookback
        self.maxFiles = maxFiles
    }

    public func recentSessionFiles(now: Date) throws -> [URL] {
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [(url: URL, modified: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true, let modified = values.contentModificationDate else { continue }
            guard now.timeIntervalSince(modified) <= lookback else { continue }
            files.append((url, modified))
        }

        return files
            .sorted { lhs, rhs in lhs.modified > rhs.modified }
            .prefix(maxFiles)
            .map(\.url)
    }

    public func recentLines(from file: URL, maxBytes: Int = 512 * 1024) throws -> [String] {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try handle.seek(toOffset: start)
        let data = try handle.readToEnd() ?? Data()
        var text = String(data: data, encoding: .utf8) ?? ""

        if start > 0, let newline = text.firstIndex(of: "\n") {
            text.removeSubrange(text.startIndex...newline)
        }

        return text
            .split(separator: "\n")
            .suffix(250)
            .map(String.init)
    }
}

public final class SessionFileActivityDetector: CodexActivityDetecting {
    public let strategyName = "Codex session JSONL"

    private enum MeaningfulEvent: Equatable {
        case active(Date, String)
        case idleBoundary(Date, String)
    }

    private let provider: SessionFileProviding
    private let activeStalenessInterval: TimeInterval
    private let staleSessionDetectedInterval: TimeInterval

    public init(
        provider: SessionFileProviding,
        activeStalenessInterval: TimeInterval = 15 * 60,
        staleSessionDetectedInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.provider = provider
        self.activeStalenessInterval = activeStalenessInterval
        self.staleSessionDetectedInterval = staleSessionDetectedInterval
    }

    public convenience init(paths: CodexSystemPaths = CodexSystemPaths()) {
        self.init(provider: FileSystemSessionFileProvider(sessionsDirectory: paths.sessionsDirectory))
    }

    public func snapshot(now: Date) async -> CodexActivitySnapshot {
        do {
            let files = try provider.recentSessionFiles(now: now)
            guard !files.isEmpty else {
                return .idle(strategy: strategyName, detail: "No Codex session files found.", observedAt: now)
            }

            let events = try files.flatMap { file in
                try provider.recentLines(from: file, maxBytes: 512 * 1024).compactMap(parseMeaningfulEvent)
            }

            guard let latest = events.sorted(by: eventSort).last else {
                return .idle(
                    detected: true,
                    strategy: strategyName,
                    detail: "Codex session files exist, but no active-work event was found.",
                    observedAt: now
                )
            }

            switch latest {
            case .active(let date, let detail):
                let isFresh = now.timeIntervalSince(date) <= activeStalenessInterval
                return CodexActivitySnapshot(
                    codexDetected: now.timeIntervalSince(date) <= staleSessionDetectedInterval,
                    workState: isFresh ? .active : .idle,
                    detectionStrategy: strategyName,
                    detail: isFresh ? detail : "Last active session event is stale: \(detail)",
                    observedAt: now
                )
            case .idleBoundary(let date, let detail):
                return .idle(
                    detected: now.timeIntervalSince(date) <= staleSessionDetectedInterval,
                    strategy: strategyName,
                    detail: detail,
                    observedAt: now
                )
            }
        } catch {
            return .idle(
                strategy: strategyName,
                detail: "Unable to read Codex session files: \(error.localizedDescription)",
                observedAt: now
            )
        }
    }

    private func eventSort(lhs: MeaningfulEvent, rhs: MeaningfulEvent) -> Bool {
        eventDate(lhs) < eventDate(rhs)
    }

    private func eventDate(_ event: MeaningfulEvent) -> Date {
        switch event {
        case .active(let date, _), .idleBoundary(let date, _):
            return date
        }
    }

    private func parseMeaningfulEvent(line: String) -> MeaningfulEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestampString = object["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter.codexSleepGuard.date(from: timestampString),
              let type = object["type"] as? String,
              let payload = object["payload"] as? [String: Any]
        else {
            return nil
        }

        if type == "response_item" {
            return parseResponseItem(payload: payload, timestamp: timestamp)
        }

        if type == "event_msg" {
            return parseEventMessage(payload: payload, timestamp: timestamp)
        }

        return nil
    }

    private func parseResponseItem(payload: [String: Any], timestamp: Date) -> MeaningfulEvent? {
        guard let payloadType = payload["type"] as? String else { return nil }

        switch payloadType {
        case "function_call":
            let name = payload["name"] as? String ?? "tool"
            return .active(timestamp, "Codex started tool call: \(name).")
        case "function_call_output":
            return .active(timestamp, "Codex received tool output.")
        case "reasoning":
            return .active(timestamp, "Codex is reasoning.")
        case "message":
            let phase = payload["phase"] as? String
            let role = payload["role"] as? String
            if role == "assistant", phase == "final" {
                return .idleBoundary(timestamp, "Codex emitted a final assistant response.")
            }
            if role == "assistant", phase == "commentary" {
                return .active(timestamp, "Codex emitted an in-progress update.")
            }
            if role == "user" {
                return .active(timestamp, "User submitted a task to Codex.")
            }
            return nil
        default:
            return nil
        }
    }

    private func parseEventMessage(payload: [String: Any], timestamp: Date) -> MeaningfulEvent? {
        guard let payloadType = payload["type"] as? String else { return nil }

        switch payloadType {
        case "agent_message":
            let phase = payload["phase"] as? String
            if phase == "final" {
                return .idleBoundary(timestamp, "Codex emitted a final assistant response.")
            }
            return .active(timestamp, "Codex emitted an in-progress update.")
        case "thread_goal_updated", "token_count":
            return .active(timestamp, "Codex session telemetry updated.")
        default:
            return nil
        }
    }
}

private extension ISO8601DateFormatter {
    static let codexSleepGuard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
