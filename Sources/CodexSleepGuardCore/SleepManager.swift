import Combine
import Foundation
import IOKit.pwr_mgt

public protocol SleepManaging: AnyObject {
    var isProtectionEnabled: Bool { get }
    func enableProtection(reason: String) throws
    func disableProtection()
}

public enum SleepManagerError: Error, Equatable, LocalizedError {
    case assertionCreateFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .assertionCreateFailed(let code):
            return "IOPMAssertionCreateWithName failed with code \(code)."
        }
    }
}

public final class SleepManager: ObservableObject, SleepManaging {
    @Published public private(set) var isProtectionEnabled: Bool = false
    @Published public private(set) var lastError: String?

    private var assertionID: IOPMAssertionID = 0

    public init() {}

    deinit {
        disableProtection()
    }

    public func enableProtection(reason: String = "Codex is actively executing work") throws {
        guard !isProtectionEnabled else { return }

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            lastError = SleepManagerError.assertionCreateFailed(result).localizedDescription
            throw SleepManagerError.assertionCreateFailed(result)
        }

        assertionID = newAssertionID
        isProtectionEnabled = true
        lastError = nil
    }

    public func disableProtection() {
        guard isProtectionEnabled else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isProtectionEnabled = false
    }
}

public final class MockSleepManager: SleepManaging {
    public private(set) var isProtectionEnabled: Bool = false
    public private(set) var enableCount = 0
    public private(set) var disableCount = 0
    public var enableError: Error?

    public init() {}

    public func enableProtection(reason: String) throws {
        if let enableError {
            throw enableError
        }
        if !isProtectionEnabled {
            enableCount += 1
        }
        isProtectionEnabled = true
    }

    public func disableProtection() {
        if isProtectionEnabled {
            disableCount += 1
        }
        isProtectionEnabled = false
    }
}
