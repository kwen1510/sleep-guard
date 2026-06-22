import Combine
import Foundation

@MainActor
public final class DiagnosticsManager: ObservableObject {
    @Published public private(set) var rawAssertions = ""
    @Published public private(set) var activeAssertions: [String] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastUpdated: Date?

    private let commandRunner: CommandRunning

    public init(commandRunner: CommandRunning = ShellCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func refresh() async {
        do {
            let output = try await commandRunner.run(
                executable: URL(fileURLWithPath: "/usr/bin/pmset"),
                arguments: ["-g", "assertions"]
            )
            rawAssertions = output
            activeAssertions = DiagnosticsManager.parseAssertionOwners(from: output)
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = error.localizedDescription
            rawAssertions = ""
            activeAssertions = []
        }
    }

    nonisolated public static func parseAssertionOwners(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { line in
                line.contains("pid ") || line.contains("id=") || line.contains("PreventUserIdleSystemSleep")
            }
    }
}
