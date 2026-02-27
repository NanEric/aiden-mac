import SwiftUI
import AidenShared

struct SettingsView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLI Settings").font(.title3).bold()

            ForEach(CliProvider.allCases, id: \.self) { provider in
                let state = viewModel.cliStates.first(where: { $0.provider == provider })
                HStack {
                    Text(provider.rawValue.capitalized)
                    Spacer()
                    if state?.installed == true {
                        Toggle("Enabled", isOn: Binding(
                            get: { state?.enabled == true },
                            set: { viewModel.toggleProvider(provider, enabled: $0) }
                        ))
                        .labelsHidden()
                    } else {
                        Text("请先安装")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 220)
    }
}
