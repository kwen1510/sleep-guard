import Combine
import Foundation

public final class GracePeriodManager: ObservableObject {
    @Published public private(set) var remainingSeconds: TimeInterval = 0

    public let duration: TimeInterval

    public var isRunning: Bool {
        remainingSeconds > 0
    }

    public init(duration: TimeInterval = 5 * 60) {
        self.duration = duration
    }

    public func start() {
        remainingSeconds = duration
    }

    public func cancel() {
        remainingSeconds = 0
    }

    public func tick(by elapsed: TimeInterval = 1) {
        guard remainingSeconds > 0 else { return }
        remainingSeconds = max(0, remainingSeconds - elapsed)
    }
}
