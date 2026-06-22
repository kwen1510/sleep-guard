import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    public static let guardEnabledDefaultsKey = "CodexSleepGuard.guardEnabled"

    @Published public private(set) var guardEnabled = true
    @Published public private(set) var codexDetected = false
    @Published public private(set) var codexActivity: CodexWorkState = .idle
    @Published public private(set) var sleepProtectionEnabled = false
    @Published public private(set) var statusText = "Idle"
    @Published public private(set) var currentDetectionStrategy = "Not checked yet"
    @Published public private(set) var detectionDetail = ""
    @Published public private(set) var protectionDuration: TimeInterval = 0
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastUpdated: Date?

    public let gracePeriod: GracePeriodManager

    private let detector: CodexActivityDetecting
    private let sleepManager: SleepManaging
    private var monitorTask: Task<Void, Never>?
    private var protectionStartedAt: Date?
    private var wasActive = false
    private let refreshInterval: TimeInterval
    private let userDefaults: UserDefaults?

    public init(
        detector: CodexActivityDetecting,
        sleepManager: SleepManaging,
        gracePeriod: GracePeriodManager = GracePeriodManager(),
        refreshInterval: TimeInterval = 5,
        userDefaults: UserDefaults? = nil,
        guardEnabled: Bool? = nil
    ) {
        self.detector = detector
        self.sleepManager = sleepManager
        self.gracePeriod = gracePeriod
        self.refreshInterval = refreshInterval
        self.userDefaults = userDefaults
        self.guardEnabled = guardEnabled ?? Self.storedGuardEnabled(in: userDefaults)
        self.statusText = self.guardEnabled ? "Idle" : "Off"
    }

    public convenience init() {
        self.init(
            detector: CompositeCodexActivityDetector(),
            sleepManager: SleepManager(),
            userDefaults: .standard
        )
    }

    deinit {
        monitorTask?.cancel()
    }

    public var remainingGracePeriod: TimeInterval {
        gracePeriod.remainingSeconds
    }

    public func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
                await MainActor.run {
                    self.advanceGrace(by: self.refreshInterval, now: Date())
                }
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    public func refresh(now: Date = Date()) async {
        let snapshot = await detector.snapshot(now: now)
        apply(snapshot: snapshot, now: now)
    }

    public func setGuardEnabled(_ enabled: Bool, now: Date = Date()) {
        guardEnabled = enabled
        userDefaults?.set(enabled, forKey: Self.guardEnabledDefaultsKey)
        reconcileProtectionState(now: now)
    }

    public func apply(snapshot: CodexActivitySnapshot, now: Date = Date()) {
        codexDetected = snapshot.codexDetected
        codexActivity = snapshot.workState
        currentDetectionStrategy = snapshot.detectionStrategy
        detectionDetail = snapshot.detail
        lastUpdated = now

        reconcileProtectionState(now: now)
    }

    public func advanceGrace(by elapsed: TimeInterval, now: Date = Date()) {
        guard guardEnabled else {
            reconcileProtectionState(now: now)
            return
        }

        gracePeriod.tick(by: elapsed)
        if codexActivity == .idle && !gracePeriod.isRunning {
            disableProtection()
            statusText = "Idle"
        }
        syncProtectionState(now: now)
    }

    private static func storedGuardEnabled(in userDefaults: UserDefaults?) -> Bool {
        guard let userDefaults,
              userDefaults.object(forKey: guardEnabledDefaultsKey) != nil
        else {
            return true
        }

        return userDefaults.bool(forKey: guardEnabledDefaultsKey)
    }

    private func reconcileProtectionState(now: Date) {
        guard guardEnabled else {
            gracePeriod.cancel()
            wasActive = false
            disableProtection()
            statusText = "Off"
            syncProtectionState(now: now)
            return
        }

        if codexActivity == .active {
            gracePeriod.cancel()
            enableProtection(now: now)
            wasActive = true
            statusText = "Protected"
        } else {
            if wasActive && !gracePeriod.isRunning {
                gracePeriod.start()
            }

            wasActive = false

            if gracePeriod.isRunning {
                enableProtection(now: now)
                statusText = "Protected"
            } else {
                disableProtection()
                statusText = "Idle"
            }
        }

        syncProtectionState(now: now)
    }

    private func enableProtection(now: Date) {
        do {
            try sleepManager.enableProtection(reason: "Codex Sleep Guard: Codex is actively executing work")
            if protectionStartedAt == nil {
                protectionStartedAt = now
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func disableProtection() {
        sleepManager.disableProtection()
        protectionStartedAt = nil
    }

    private func syncProtectionState(now: Date) {
        sleepProtectionEnabled = sleepManager.isProtectionEnabled
        if let protectionStartedAt, sleepManager.isProtectionEnabled {
            protectionDuration = max(0, now.timeIntervalSince(protectionStartedAt))
        } else {
            protectionDuration = 0
        }
    }
}
