import Foundation

final class UserStateService {
    private let store = OnboardingStateStore()

    var onboardingCompleted: Bool {
        get { store.completed }
        set { store.completed = newValue }
    }
}
