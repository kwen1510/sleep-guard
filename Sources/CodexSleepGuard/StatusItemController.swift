import AppKit
import CodexSleepGuardCore
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private let carryMode: CarryModeManager
    private let diagnostics: DiagnosticsManager
    private let launchAtLogin: LaunchAtLoginManager
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var controlWindowController: NSWindowController?
    private var diagnosticsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    init(
        appState: AppState,
        carryMode: CarryModeManager,
        diagnostics: DiagnosticsManager,
        launchAtLogin: LaunchAtLoginManager
    ) {
        self.appState = appState
        self.carryMode = carryMode
        self.diagnostics = diagnostics
        self.launchAtLogin = launchAtLogin
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindStatusUpdates()
        updateStatusItem()
    }

    func showControlWindow() {
        if controlWindowController == nil {
            controlWindowController = makeControlWindowController()
        }

        controlWindowController?.showWindow(nil)
        controlWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureStatusItem() {
        statusItem.isVisible = true
        statusItem.length = NSStatusItem.squareLength

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("Codex Sleep Guard")
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: StatusMenuView(
                appState: appState,
                carryMode: carryMode,
                launchAtLogin: launchAtLogin,
                openDiagnostics: { [weak self] in
                    self?.showDiagnostics()
                }
            )
        )
    }

    private func bindStatusUpdates() {
        Publishers.MergeMany(
            appState.$guardEnabled.map { _ in () }.eraseToAnyPublisher(),
            appState.$sleepProtectionEnabled.map { _ in () }.eraseToAnyPublisher(),
            appState.$statusText.map { _ in () }.eraseToAnyPublisher(),
            carryMode.$isEnabled.map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in
            self?.updateStatusItem()
        }
        .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        statusItem.isVisible = true
        button.title = ""
        button.image = statusImage()
        button.contentTintColor = carryMode.isEnabled ? .systemRed : nil
        button.toolTip = statusTooltip
        button.setAccessibilityLabel(statusAccessibilityDescription)
    }

    private func statusImage() -> NSImage? {
        if carryMode.isEnabled {
            let image = NSImage(
                systemSymbolName: "exclamationmark.shield.fill",
                accessibilityDescription: statusAccessibilityDescription
            )
            image?.size = NSSize(width: 20, height: 20)
            image?.isTemplate = true
            return image
        }

        let image = NSImage(named: "ShieldLogo")
            ?? NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: statusAccessibilityDescription)
        image?.size = NSSize(width: 20, height: 20)
        image?.isTemplate = false
        return image
    }

    private var statusSymbolName: String {
        if !appState.guardEnabled {
            return "power.circle"
        }

        return appState.sleepProtectionEnabled ? "bolt.shield.fill" : "power.circle.fill"
    }

    private var statusAccessibilityDescription: String {
        if !appState.guardEnabled {
            return "Codex Sleep Guard is off"
        }

        if carryMode.isEnabled {
            return "Codex Sleep Guard Carry Mode is on"
        }

        return appState.sleepProtectionEnabled
            ? "Codex Sleep Guard is preventing idle sleep"
            : "Codex Sleep Guard is on"
    }

    private var statusTooltip: String {
        if !appState.guardEnabled {
            return "Codex Sleep Guard: Off"
        }

        if carryMode.isEnabled {
            return "Codex Sleep Guard: Carry Mode ON"
        }

        return appState.sleepProtectionEnabled
            ? "Codex Sleep Guard: preventing idle sleep"
            : "Codex Sleep Guard: On"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showDiagnostics() {
        popover.performClose(nil)

        if diagnosticsWindowController == nil {
            diagnosticsWindowController = makeDiagnosticsWindowController()
        }

        diagnosticsWindowController?.showWindow(nil)
        diagnosticsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await diagnostics.refresh() }
    }

    private func makeControlWindowController() -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Sleep Guard"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: StatusMenuView(
                appState: appState,
                carryMode: carryMode,
                launchAtLogin: launchAtLogin,
                openDiagnostics: { [weak self] in
                    self?.showDiagnostics()
                }
            )
        )

        return NSWindowController(window: window)
    }

    private func makeDiagnosticsWindowController() -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Diagnostics"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: DiagnosticsView(diagnostics: diagnostics)
                .frame(minWidth: 680, minHeight: 520)
        )

        return NSWindowController(window: window)
    }
}
