import SwiftUI

struct AgentStatusBadgeView: View {
    let status: AgentRunStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .completed:
            return .green.opacity(0.15)
        case .failed:
            return .red.opacity(0.15)
        case .running:
            return .blue.opacity(0.15)
        case .queued:
            return .orange.opacity(0.15)
        case .cancelled:
            return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .completed:
            return .green
        case .failed:
            return .red
        case .running:
            return .blue
        case .queued:
            return .orange
        case .cancelled:
            return .secondary
        }
    }
}
