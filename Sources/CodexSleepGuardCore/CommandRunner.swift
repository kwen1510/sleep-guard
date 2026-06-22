import Foundation

public protocol CommandRunning {
    func run(executable: URL, arguments: [String]) async throws -> String
}

public final class ShellCommandRunner: CommandRunning {
    public init() {}

    public func run(executable: URL, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            let error = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = error
            try process.run()

            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = error.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""
            return text.isEmpty ? errorText : text
        }.value
    }
}
