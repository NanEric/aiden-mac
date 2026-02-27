import SwiftUI

struct StartupLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Starting Services...")
        }
        .padding(20)
    }
}
