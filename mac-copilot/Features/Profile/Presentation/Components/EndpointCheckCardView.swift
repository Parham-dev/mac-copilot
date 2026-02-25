import SwiftUI

struct EndpointCheckCardView: View {
    let check: EndpointCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: check.available ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(check.available ? .green : .orange)
                Text(check.name)
                Text("(\(check.statusCode))")
                    .foregroundStyle(.secondary)
            }

            Text(check.path)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(check.preview)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
