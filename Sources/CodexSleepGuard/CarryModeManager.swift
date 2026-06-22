import Combine
import CodexSleepGuardCore
import Foundation

@MainActor
final class CarryModeManager: ObservableObject {
    static let autoDisableDefaultsKey = "CodexSleepGuard.carryMode.autoDisable"

    @Published private(set) var isEnabled = false
    @Published private(set) var isChanging = false
    @Published private(set) var statusText = "Off"
    @Published private(set) var lastError: String?
    @Published private(set) var requiresApproval = false
    @Published var autoDisableWhenCodexFinishes: Bool {
        didSet {
            userDefaults?.set(autoDisableWhenCodexFinishes, forKey: Self.autoDisableDefaultsKey)
        }
    }

    private let appState: AppState
    private let helper: PowerHelperClient
    private let authenticator: CarryModeAuthenticating
    private let userDefaults: UserDefaults?
    private var cancellables = Set<AnyCancellable>()
    private var sawSleepProtectionWhileEnabled = false

    init(
        appState: AppState,
        helper: PowerHelperClient = .shared,
        authenticator: CarryModeAuthenticating = LocalCarryModeAuthenticator(),
        userDefaults: UserDefaults? = .standard
    ) {
        self.appState = appState
        self.helper = helper
        self.authenticator = authenticator
        self.userDefaults = userDefaults
        self.autoDisableWhenCodexFinishes = Self.storedAutoDisable(in: userDefaults)

        bindAppState()
    }

    func setEnabled(_ enabled: Bool) async {
        enabled ? await enable() : await disable()
    }

    func openApprovalSettings() {
        helper.openHelperApprovalSettings()
    }

    func disableForTermination() async {
        guard isEnabled else { return }
        await disable()
    }

    private func enable() async {
        guard !isEnabled, !isChanging else { return }

        isChanging = true
        requiresApproval = false
        lastError = nil
        statusText = "Authenticating"
        var sleepDisableWasRequested = false

        do {
            try await authenticator.authenticateForCarryMode()
            statusText = "Turning on"
            try await helper.setSleepDisabled(true)
            sleepDisableWasRequested = true
            guard try await helper.isSleepDisabled() else {
                throw CarryModeError.verificationFailed
            }

            isEnabled = true
            sawSleepProtectionWhileEnabled = appState.sleepProtectionEnabled
            statusText = "On"
        } catch {
            isEnabled = false
            sawSleepProtectionWhileEnabled = false
            if sleepDisableWasRequested {
                try? await helper.setSleepDisabled(false)
            }
            lastError = error.localizedDescription
            requiresApproval = error.localizedDescription.localizedCaseInsensitiveContains("approve")
            statusText = requiresApproval ? "Needs approval" : "Error"
        }

        isChanging = false
    }

    private func disable() async {
        guard (isEnabled || isChanging) else { return }

        isChanging = true
        lastError = nil
        statusText = "Turning off"

        do {
            try await helper.setSleepDisabled(false)
            guard try await !helper.isSleepDisabled() else {
                throw CarryModeError.restoreFailed
            }

            isEnabled = false
            sawSleepProtectionWhileEnabled = false
            requiresApproval = false
            statusText = "Off"
        } catch {
            lastError = error.localizedDescription
            statusText = "Restore failed"
        }

        isChanging = false
    }

    private func bindAppState() {
        Publishers.CombineLatest(appState.$guardEnabled, appState.$sleepProtectionEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] guardEnabled, sleepProtectionEnabled in
                Task { @MainActor [weak self] in
                    await self?.handleGuardStateChanged(
                        guardEnabled: guardEnabled,
                        sleepProtectionEnabled: sleepProtectionEnabled
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func handleGuardStateChanged(guardEnabled: Bool, sleepProtectionEnabled: Bool) async {
        guard isEnabled, autoDisableWhenCodexFinishes else { return }

        if sleepProtectionEnabled {
            sawSleepProtectionWhileEnabled = true
            return
        }

        guard !guardEnabled || sawSleepProtectionWhileEnabled else { return }
        await disable()
    }

    private static func storedAutoDisable(in userDefaults: UserDefaults?) -> Bool {
        guard let userDefaults,
              userDefaults.object(forKey: autoDisableDefaultsKey) != nil
        else {
            return true
        }

        return userDefaults.bool(forKey: autoDisableDefaultsKey)
    }
}

private enum CarryModeError: LocalizedError {
    case verificationFailed
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Could not verify lid-closed sleep prevention."
        case .restoreFailed:
            return "Could not verify normal sleep restoration. Run sudo pmset -a disablesleep 0 if needed."
        }
    }
}
