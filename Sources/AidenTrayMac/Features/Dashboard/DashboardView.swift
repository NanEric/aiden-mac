import SwiftUI
import AidenShared

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ForEach(CliProvider.allCases, id: \.self) { provider in
                        Button(provider.rawValue.capitalized) {
                            viewModel.setProvider(provider)
                        }
                        .disabled(!viewModel.isTabEnabled(provider))
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !viewModel.hasAnyAvailableTab {
                    Text("No enabled CLI data source. Please enable one in Settings.")
                        .foregroundStyle(.secondary)
                } else if let snapshot = viewModel.snapshotForCurrentTab() {
                    metricLine("Input Tokens", format(snapshot.inputTokens))
                    metricLine("Output Tokens", format(snapshot.outputTokens))
                    metricLine("Current User Email", snapshot.currentUserEmail)
                    metricLine("User Active", snapshot.userActiveDays.map { "\($0) days" } ?? "N/A")
                    metricLine("Cost USD", String(format: "%.6f", snapshot.costUsd))
                    metricLine("Context", contextText(snapshot))
                    metricLine("Status", snapshot.status)
                } else {
                    Text("No data")
                }

                if let updated = viewModel.state.lastUpdatedAt {
                    Text("Last Updated: \(updated.formatted())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Refresh") { viewModel.refresh() }
                    Button("Settings") {
                        viewModel.reloadCliStates()
                        showSettings = true
                    }
                    Button("Exit UI") { WindowRouter.closeAppUIOnly() }
                }
            }
            .padding(14)
            .frame(width: 400)

            if showSettings {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { showSettings = false }

                SettingsView(viewModel: viewModel) {
                    showSettings = false
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 10)
            }
        }
    }

    private func metricLine(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).bold()
            Spacer()
            Text(value)
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.0f", value)
    }

    private func contextText(_ snapshot: TelemetrySnapshot) -> String {
        guard let m = snapshot.contextM, let p = snapshot.contextPercent else { return "N/A" }
        return String(format: "%.3fM (%.1f%%)", m, p)
    }
}
