import Foundation
import SwiftUI
import AidenShared

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state = DashboardState()
    @Published var cliStates: [CliState] = []

    private let telemetryService = TelemetryService()
    private let provisioningService = CliProvisioningService()
    private let config = ConfigService().load()

    init() {
        reloadCliStates()
        telemetryService.startPolling(seconds: config.polling.seconds) { [weak self] status, snapshots in
            guard let self else { return }
            self.state.runtimeStatus = status
            self.state.snapshots = snapshots
            self.state.lastUpdatedAt = Date()
            self.autoFallbackTabIfNeeded()
        }
    }

    func refresh() {
        Task { @MainActor in
            await telemetryService.refreshNow()
        }
    }

    func reloadCliStates() {
        cliStates = provisioningService.states()
        autoFallbackTabIfNeeded()
    }

    func isTabEnabled(_ provider: CliProvider) -> Bool {
        cliStates.first(where: { $0.provider == provider })?.available == true
    }

    var hasAnyAvailableTab: Bool {
        cliStates.contains(where: { $0.available })
    }

    func setProvider(_ provider: CliProvider) {
        guard isTabEnabled(provider) else { return }
        state.selectedProvider = provider
    }

    func snapshotForCurrentTab() -> TelemetrySnapshot? {
        state.snapshots[state.selectedProvider]
    }

    func toggleProvider(_ provider: CliProvider, enabled: Bool) {
        provisioningService.setEnabled(enabled, provider: provider)
        reloadCliStates()
    }

    private func autoFallbackTabIfNeeded() {
        if isTabEnabled(state.selectedProvider) { return }
        for provider in [CliProvider.gemini, .codex, .claude] {
            if isTabEnabled(provider) {
                state.selectedProvider = provider
                return
            }
        }
    }
}
