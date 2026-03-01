import SwiftUI

struct AgentUploadedFileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: String
}

struct AgentUploadedFilesListView: View {
    let files: [AgentUploadedFileItem]
    let onRemove: (UUID) -> Void
    let onAddMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(files) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.callout)
                            .lineLimit(1)
                        Text(file.type.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button(role: .destructive) {
                        onRemove(file.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                onAddMore()
            } label: {
                Label("Add More Files", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
}
