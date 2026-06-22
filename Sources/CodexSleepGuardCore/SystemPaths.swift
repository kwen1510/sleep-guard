import Foundation

public struct CodexSystemPaths: Equatable {
    public var codexHome: URL

    public init(codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) {
        self.codexHome = codexHome
    }

    public var sessionsDirectory: URL {
        codexHome.appendingPathComponent("sessions", isDirectory: true)
    }

    public var processManagerFile: URL {
        codexHome
            .appendingPathComponent("process_manager", isDirectory: true)
            .appendingPathComponent("chat_processes.json")
    }
}
