import SwiftUI

extension ProfileView {
    @ViewBuilder
    var rightPane: some View {
        if viewModel.checks.isEmpty && !viewModel.isLoading {
            VStack(alignment: .leading, spacing: 8) {
                Text("Endpoint Checks")
                    .font(.headline)
                Text("Refresh to run endpoint availability checks against the GitHub Copilot API.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Endpoint Checks")
                            .font(.headline)
                        Spacer()
                        let available = viewModel.checks.filter(\.available).count
                        Text("\(available)/\(viewModel.checks.count) available")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    if viewModel.isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            endpointCheckPlaceholder
                        }
                    } else {
                        ForEach(viewModel.checks) { check in
                            ProfileEndpointCheckRow(check: check)
                            if check.id != viewModel.checks.last?.id {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    var endpointCheckPlaceholder: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 160, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 100, height: 11)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
