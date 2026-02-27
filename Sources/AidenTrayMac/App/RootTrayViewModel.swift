import Foundation
import AppKit

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
    private let userState = UserStateService()

    func bootstrap() {
        phase = .loading
        Task { @MainActor in
            do {
                if !(await agentClient.healthz()) {
                    await agentClient.restart()
                }
                let status = try await agentClient.status()
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
            await agentClient.restart()
            bootstrap()
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
}
