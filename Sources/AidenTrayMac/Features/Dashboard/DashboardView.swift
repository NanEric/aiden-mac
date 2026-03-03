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
                        Button {
                            viewModel.setProvider(provider)
                        } label: {
                            tabLabel(for: provider)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.tabDisplayState(provider) == .invalid || !viewModel.isTabEnabled(provider))
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

    private func tabLabel(for provider: CliProvider) -> some View {
        let state = viewModel.tabDisplayState(provider)
        return HStack(spacing: 6) {
            Text(provider.rawValue.capitalized)
                .font(.subheadline.weight(.semibold))
            if state == .invalid {
                Text("Invalid")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 110)
        .background(backgroundColor(for: state))
        .foregroundStyle(textColor(for: state))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor(for: state), lineWidth: 1)
        )
    }

    private func backgroundColor(for state: DashboardViewModel.TabDisplayState) -> Color {
        switch state {
        case .selected:
            return .accentColor
        case .normal:
            return Color.gray.opacity(0.14)
        case .invalid:
            return Color.gray.opacity(0.08)
        }
    }

    private func textColor(for state: DashboardViewModel.TabDisplayState) -> Color {
        switch state {
        case .selected:
            return .white
        case .normal:
            return .primary
        case .invalid:
            return .secondary
        }
    }

    private func borderColor(for state: DashboardViewModel.TabDisplayState) -> Color {
        switch state {
        case .selected:
            return .accentColor
        case .normal:
            return Color.gray.opacity(0.28)
        case .invalid:
            return Color.red.opacity(0.35)
        }
    }
}
