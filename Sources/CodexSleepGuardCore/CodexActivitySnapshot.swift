import Foundation

public enum CodexWorkState: Equatable {
    case active
    case idle

    public var isActive: Bool {
        self == .active
    }
}

public struct CodexActivitySnapshot: Equatable {
    public var codexDetected: Bool
    public var workState: CodexWorkState
    public var detectionStrategy: String
    public var detail: String
    public var observedAt: Date

    public init(
        codexDetected: Bool,
        workState: CodexWorkState,
        detectionStrategy: String,
        detail: String,
        observedAt: Date = Date()
    ) {
        self.codexDetected = codexDetected
        self.workState = workState
        self.detectionStrategy = detectionStrategy
        self.detail = detail
        self.observedAt = observedAt
    }

    public static func idle(
        detected: Bool = false,
        strategy: String,
        detail: String,
        observedAt: Date = Date()
    ) -> CodexActivitySnapshot {
        CodexActivitySnapshot(
            codexDetected: detected,
            workState: .idle,
            detectionStrategy: strategy,
            detail: detail,
            observedAt: observedAt
        )
    }

    public static func active(
        detected: Bool = true,
        strategy: String,
        detail: String,
        observedAt: Date = Date()
    ) -> CodexActivitySnapshot {
        CodexActivitySnapshot(
            codexDetected: detected,
            workState: .active,
            detectionStrategy: strategy,
            detail: detail,
            observedAt: observedAt
        )
    }
}
