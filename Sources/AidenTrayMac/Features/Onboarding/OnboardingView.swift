import SwiftUI
import AidenShared

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("首次引导").font(.title2).bold()
            Text("至少开通一个 CLI 才可继续")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(CliProvider.allCases, id: \.self) { provider in
                let state = viewModel.states.first(where: { $0.provider == provider })
                HStack {
                    Text(provider.rawValue.capitalized)
                    Spacer()
                    if state?.installed == true {
                        Toggle(
                            "Enabled",
                            isOn: Binding(
                                get: { state?.enabled == true },
                                set: { viewModel.set(provider: provider, enabled: $0) }
                            )
                        )
                        .labelsHidden()
                    } else {
                        Text("请先安装")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Continue") { onContinue() }
                    .disabled(!viewModel.canContinue)
                Button("Exit") { onExit() }
            }
        }
        .padding(16)
    }
}
