import CodexSleepGuardCore
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var carryMode: CarryModeManager
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    let openDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image("ShieldLogo")
                    .resizable()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Sleep Guard")
                        .font(.headline)
                    Text(appState.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { appState.guardEnabled },
                set: { enabled in
                    appState.setGuardEnabled(enabled)
                    if enabled {
                        Task { await appState.refresh() }
                    }
                }
            )) {
                Label("Prevent sleep while Codex works", systemImage: appState.guardEnabled ? "power.circle.fill" : "power.circle")
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: carryMode.isEnabled ? "exclamationmark.shield.fill" : "shield")
                        .foregroundStyle(carryMode.isEnabled ? .red : .secondary)

                    Toggle(isOn: Binding(
                        get: { carryMode.isEnabled },
                        set: { enabled in
                            Task { await carryMode.setEnabled(enabled) }
                        }
                    )) {
                        Text("Carry Mode")
                            .fontWeight(.semibold)
                            .foregroundStyle(carryMode.isEnabled ? .red : .primary)
                    }
                    .toggleStyle(.switch)
                    .disabled(carryMode.isChanging)
                }

                Text("Keeps the Mac awake while the lid is closed by changing a system sleep setting.")
                    .font(.caption)
                    .foregroundStyle(carryMode.isEnabled ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Auto off when Codex finishes", isOn: $carryMode.autoDisableWhenCodexFinishes)
                    .font(.caption)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 6) {
                    StatusRow(label: "Carry Mode", value: carryMode.statusText)
                    StatusRow(label: "Recovery", value: "sudo pmset -a disablesleep 0")
                }

                if carryMode.requiresApproval {
                    Button("Open Approval Settings") {
                        carryMode.openApprovalSettings()
                    }
                }

                if let error = carryMode.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(carryMode.isEnabled ? Color.red.opacity(0.14) : Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(carryMode.isEnabled ? Color.red.opacity(0.65) : Color.secondary.opacity(0.2))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 8) {
                StatusRow(label: "Status", value: appState.statusText)
                StatusRow(label: "Guard Switch", value: appState.guardEnabled ? "On" : "Off")
                StatusRow(label: "Codex Detected", value: appState.codexDetected ? "Yes" : "No")
                StatusRow(label: "Codex Activity", value: appState.codexActivity == .active ? "Active" : "Idle")
                StatusRow(label: "Sleep Protection", value: appState.sleepProtectionEnabled ? "Enabled" : "Disabled")
                StatusRow(label: "Current Detection Strategy", value: appState.currentDetectionStrategy)
                StatusRow(label: "Protection Duration", value: DurationFormatter.string(from: appState.protectionDuration))
                StatusRow(label: "Remaining Grace Period", value: DurationFormatter.string(from: appState.remainingGracePeriod))
            }

            if !appState.detectionDetail.isEmpty {
                Text(appState.detectionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .textSelection(.enabled)
            }

            if let error = appState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))

            HStack {
                Button("Refresh") {
                    Task { await appState.refresh() }
                }

                Button("Diagnostics") {
                    openDiagnostics()
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 460)
    }

}

private struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}

enum DurationFormatter {
    static func string(from interval: TimeInterval) -> String {
        guard interval > 0 else { return "0:00" }
        let totalSeconds = Int(interval.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
