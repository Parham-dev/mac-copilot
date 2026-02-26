import SwiftUI

struct GitLoadingStatusView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading Git status…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

struct GitNoRepositoryView: View {
    let isInitializingGit: Bool
    let onInitializeGit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Text("No Git repository found")
                .font(.body)

            Button(action: onInitializeGit) {
                if isInitializingGit {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Init Git", systemImage: "plus.square.on.square")
                }
            }
            .disabled(isInitializingGit)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
