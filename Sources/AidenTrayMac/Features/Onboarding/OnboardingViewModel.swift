import Foundation
import AidenShared

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var states: [CliState] = []

    private let provisioning = CliProvisioningService()
    private let userState = UserStateService()

    init() {
        reload()
    }

    func set(provider: CliProvider, enabled: Bool) {
        provisioning.setEnabled(enabled, provider: provider)
        reload()
    }

    func reload() {
        states = provisioning.states()
    }

    var canContinue: Bool {
        states.contains(where: { $0.available })
    }

    func complete() {
        userState.onboardingCompleted = true
    }
}
