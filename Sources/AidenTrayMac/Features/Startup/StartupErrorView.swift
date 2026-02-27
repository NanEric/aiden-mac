import SwiftUI

struct StartupErrorView: View {
    let error: String
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Startup Error").font(.title3).bold()
            Text(error).foregroundStyle(.secondary)
            HStack {
                Button("Retry", action: onRetry)
                Button("Exit", action: onExit)
            }
        }
        .padding(20)
    }
}
