import SwiftUI

/// A single row in the Profile sheet's endpoint-checks list.
/// Matches the visual style of MCP Tools / Models list rows.
struct ProfileEndpointCheckRow: View {
    let check: EndpointCheck

    var body: some View {
        HStack(spacing: 12) {

            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(check.available ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: check.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(check.available ? .green : .orange)
                    .font(.system(size: 15))
            }

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(check.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // HTTP status badge
            statusBadge(check.statusCode, available: check.available)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func statusBadge(_ code: Int, available: Bool) -> some View {
        Text("\(code)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                available ? Color.green.opacity(0.12) : Color.orange.opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(available ? .green : .orange)
    }
}
