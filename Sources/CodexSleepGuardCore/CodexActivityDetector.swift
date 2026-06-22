import Foundation

public protocol CodexActivityDetecting {
    var strategyName: String { get }
    func snapshot(now: Date) async -> CodexActivitySnapshot
}

public extension CodexActivityDetecting {
    func snapshot() async -> CodexActivitySnapshot {
        await snapshot(now: Date())
    }
}

public final class StaticCodexActivityDetector: CodexActivityDetecting {
    public let strategyName = "Static"
    private let snapshotValue: CodexActivitySnapshot

    public init(snapshot: CodexActivitySnapshot) {
        self.snapshotValue = snapshot
    }

    public func snapshot(now: Date) async -> CodexActivitySnapshot {
        CodexActivitySnapshot(
            codexDetected: snapshotValue.codexDetected,
            workState: snapshotValue.workState,
            detectionStrategy: snapshotValue.detectionStrategy,
            detail: snapshotValue.detail,
            observedAt: now
        )
    }
}
