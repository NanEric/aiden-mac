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
    private var startupAutoRetryTask: Task<Void, Never>?
    private var bootstrapGeneration = 0
    private var isBootstrapInFlight = false

    deinit {
        startupAutoRetryTask?.cancel()
    }

    func bootstrap(force: Bool = false) {
        runBootstrap(force: force, showLoading: true)
    }

    private func runBootstrap(force: Bool, showLoading: Bool) {
        if hasBootstrapped && !force {
            return
        }
        if isBootstrapInFlight {
            return
        }

        hasBootstrapped = true
        isBootstrapInFlight = true
        bootstrapGeneration += 1
        let generation = bootstrapGeneration
        if showLoading {
            setPhase(.loading)
        }

        Task { @MainActor in
            defer {
                if isCurrentGeneration(generation) {
                    isBootstrapInFlight = false
                }
            }

            do {
                try runtimeBootstrapService.ensureRuntimeFiles()
                guard isCurrentGeneration(generation) else { return }

                if !(await agentClient.healthz()) {
                    if let launchError = agentLauncher.ensureStarted() {
                        guard isCurrentGeneration(generation) else { return }
                        setPhase(.startupError(launchError))
                        return
                    }
                    if !(await waitForAgentHealth()) {
                        guard isCurrentGeneration(generation) else { return }
                        setPhase(.startupError("Could not connect to the runtime agent"))
                        return
                    }
                }
                guard isCurrentGeneration(generation) else { return }

                let status = await waitForRuntimeOnline()
                guard isCurrentGeneration(generation) else { return }
                if !status.online {
                    setPhase(.startupError(status.lastError ?? "Runtime is offline"))
                    return
                }

                if shouldShowOnboarding() {
                    setPhase(.onboarding)
                } else {
                    setPhase(.dashboard)
                }
            } catch {
                guard isCurrentGeneration(generation) else { return }
                setPhase(.startupError(error.localizedDescription))
            }
        }
    }

    func retryBootstrap() {
        Task { @MainActor in
            if await agentClient.healthz() {
                await agentClient.restart()
            }
            runBootstrap(force: true, showLoading: true)
        }
    }

    func continueFromOnboarding() {
        onboardingViewModel.complete()
        dashboardViewModel.reloadCliStates()
        setPhase(.dashboard)
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

    private func setPhase(_ next: Phase) {
        phase = next
        switch next {
        case .startupError:
            startStartupAutoRetryLoopIfNeeded()
        case .loading, .onboarding, .dashboard:
            stopStartupAutoRetryLoop()
        }
    }

    private func startStartupAutoRetryLoopIfNeeded() {
        guard startupAutoRetryTask == nil else { return }
        startupAutoRetryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                await self.runStartupAutoRetryTick()
            }
        }
    }

    private func stopStartupAutoRetryLoop() {
        startupAutoRetryTask?.cancel()
        startupAutoRetryTask = nil
    }

    private func runStartupAutoRetryTick() async {
        guard case .startupError = phase else {
            stopStartupAutoRetryLoop()
            return
        }
        guard !isBootstrapInFlight else { return }
        runBootstrap(force: true, showLoading: false)
    }

    private func isCurrentGeneration(_ generation: Int) -> Bool {
        generation == bootstrapGeneration
    }
}
