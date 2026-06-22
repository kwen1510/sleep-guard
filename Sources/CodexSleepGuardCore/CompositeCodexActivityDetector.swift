import Foundation

public final class CompositeCodexActivityDetector: CodexActivityDetecting {
    public let strategyName = "Composite detector"
    private let detectors: [CodexActivityDetecting]

    public init(detectors: [CodexActivityDetecting]) {
        self.detectors = detectors
    }

    public convenience init(paths: CodexSystemPaths = CodexSystemPaths()) {
        self.init(detectors: [
            SessionFileActivityDetector(paths: paths),
            ManagedProcessActivityDetector(paths: paths),
            CodexProcessDetector()
        ])
    }

    public func snapshot(now: Date) async -> CodexActivitySnapshot {
        guard !detectors.isEmpty else {
            return .idle(strategy: strategyName, detail: "No detectors configured.", observedAt: now)
        }

        var snapshots: [CodexActivitySnapshot] = []
        for detector in detectors {
            snapshots.append(await detector.snapshot(now: now))
        }

        if let active = snapshots.first(where: { $0.workState == .active }) {
            return CodexActivitySnapshot(
                codexDetected: true,
                workState: .active,
                detectionStrategy: active.detectionStrategy,
                detail: active.detail,
                observedAt: now
            )
        }

        let detected = snapshots.contains { $0.codexDetected }
        let detail = snapshots.map { "\($0.detectionStrategy): \($0.detail)" }.joined(separator: "\n")
        return .idle(
            detected: detected,
            strategy: strategyName,
            detail: detail,
            observedAt: now
        )
    }
}
