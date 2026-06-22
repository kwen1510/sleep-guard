import AppKit
import CodexSleepGuardCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let diagnostics = DiagnosticsManager()
    private let launchAtLogin = LaunchAtLoginManager()
    private lazy var carryMode = CarryModeManager(appState: appState)
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItemController = StatusItemController(
            appState: appState,
            carryMode: carryMode,
            diagnostics: diagnostics,
            launchAtLogin: launchAtLogin
        )
        appState.startMonitoring()
        statusItemController?.showControlWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopMonitoring()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard carryMode.isEnabled else {
            return .terminateNow
        }

        Task {
            await carryMode.disableForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemController?.showControlWindow()
        return true
    }
}
