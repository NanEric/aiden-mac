import Foundation

final class OnboardingStateStore {
    private let defaults = UserDefaults.standard
    private let key = "OnboardingCompleted"

    var completed: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
