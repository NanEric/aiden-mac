import Foundation
import AppKit
import AidenShared

@MainActor
final class RootTrayViewModel: ObservableObject {
    enum Phase {
        case loading
        case startupError(String)
        case onboarding
        case dashboard
    }

    @Published var phase: Phase = .loading

    let dashboardViewModel = DashboardViewModel()
    let onboardingViewModel = OnboardingViewModel()

    private let agentClient = RuntimeAgentClient()
    private let agentLauncher = RuntimeAgentLauncher()
    private let runtimeBootstrapService = RuntimeBootstrapService()
    private let userState = UserStateService()
    private var hasBootstrapped = false

    func bootstrap(force: Bool = false) {
        if hasBootstrapped && !force {
            return
        }
        hasBootstrapped = true
        phase = .loading
        Task { @MainActor in
            do {
                try runtimeBootstrapService.ensureRuntimeFiles()

                if !(await agentClient.healthz()) {
                    if let launchError = agentLauncher.ensureStarted() {
                        phase = .startupError(launchError)
                        return
                    }
                    if !(await waitForAgentHealth()) {
                        phase = .startupError("Could not connect to the runtime agent")
                        return
                    }
                }
                let status = await waitForRuntimeOnline()
                if !status.online {
                    phase = .startupError(status.lastError ?? "Runtime is offline")
                    return
                }

                if shouldShowOnboarding() {
                    phase = .onboarding
                } else {
                    phase = .dashboard
                }
            } catch {
                phase = .startupError(error.localizedDescription)
            }
        }
    }

    func retryBootstrap() {
        Task { @MainActor in
            if await agentClient.healthz() {
                await agentClient.restart()
            }
            bootstrap(force: true)
        }
    }

    func continueFromOnboarding() {
        onboardingViewModel.complete()
        dashboardViewModel.reloadCliStates()
        phase = .dashboard
    }

    func exitApp() {
        NSApp.terminate(nil)
    }

    private func shouldShowOnboarding() -> Bool {
        if userState.onboardingCompleted { return false }
        onboardingViewModel.reload()
        let states = onboardingViewModel.states
        let allAvailable = states.count == 3 && states.allSatisfy { $0.available }
        return !allAvailable
    }

    private func waitForAgentHealth(maxAttempts: Int = 15) async -> Bool {
        for _ in 0..<maxAttempts {
            if await agentClient.healthz() {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    private func waitForRuntimeOnline(maxAttempts: Int = 20) async -> RuntimeStatus {
        var lastKnown = RuntimeStatus(
            online: false,
            collectorHealthy: false,
            vmHealthy: false,
            lastError: "Runtime is offline",
            updatedAt: Date()
        )

        for _ in 0..<maxAttempts {
            do {
                let status = try await agentClient.status()
                lastKnown = status
                if status.online {
                    return status
                }
            } catch {
                lastKnown = RuntimeStatus(
                    online: false,
                    collectorHealthy: false,
                    vmHealthy: false,
                    lastError: error.localizedDescription,
                    updatedAt: Date()
                )
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return lastKnown
    }
}
