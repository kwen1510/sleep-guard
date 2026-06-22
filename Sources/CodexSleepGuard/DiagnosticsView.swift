import CodexSleepGuardCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var diagnostics: DiagnosticsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Power Assertions")
                    .font(.title2.bold())

                Spacer()

                Button("Refresh") {
                    Task { await diagnostics.refresh() }
                }
            }

            if let lastUpdated = diagnostics.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = diagnostics.lastError {
                Text(error)
                    .foregroundStyle(.red)
            }

            if !diagnostics.activeAssertions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Assertions")
                        .font(.headline)
                    ForEach(diagnostics.activeAssertions, id: \.self) { assertion in
                        Text(assertion)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            TextEditor(text: .constant(diagnostics.rawAssertions))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .border(Color.secondary.opacity(0.25))
        }
        .padding(20)
        .task {
            await diagnostics.refresh()
        }
    }
}
