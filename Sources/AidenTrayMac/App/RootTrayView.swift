import SwiftUI

struct RootTrayView: View {
    @ObservedObject var viewModel: RootTrayViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                StartupLoadingView()
                    .frame(width: 400, height: 220)
            case .startupError(let error):
                StartupErrorView(
                    error: error,
                    onRetry: { viewModel.retryBootstrap() },
                    onExit: { viewModel.exitApp() }
                )
                .frame(width: 400, height: 220)
            case .onboarding:
                OnboardingView(
                    viewModel: viewModel.onboardingViewModel,
                    onContinue: { viewModel.continueFromOnboarding() },
                    onExit: { viewModel.exitApp() }
                )
                .frame(width: 420, height: 280)
            case .dashboard:
                DashboardView(viewModel: viewModel.dashboardViewModel)
                    .frame(width: 420, height: 420)
            }
        }
    }
}
