import SwiftUI

struct AgentRunPrimaryFieldsSectionView: View {
    let fields: [AgentInputField]
    let bindingForFieldID: (String) -> Binding<String>
    let hasUploadedFiles: Bool
    let uploadedFiles: [AgentUploadedFileItem]
    let onUploadFiles: () -> Void
    let onRemoveUploadedFile: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primary Input")
                .font(.headline)

            ForEach(fields, id: \.id) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label(for: field))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if field.type == .url {
                        urlSourceInput
                    } else {
                        GrowingTextInputView(
                            text: bindingForFieldID(field.id),
                            placeholder: placeholder(for: field),
                            minLines: 2,
                            maxLines: 6,
                            isEditable: true,
                            onShiftEnter: nil,
                            showsTextMetrics: true,
                            validationMessageProvider: nil
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func label(for field: AgentInputField) -> String {
        let base = field.type == .url ? "Source (URL or Files)" : field.label
        return field.required ? "\(base) *" : base
    }

    private func placeholder(for field: AgentInputField) -> String {
        switch field.type {
        case .url:
            return "https://example.com"
        case .text, .select:
            return field.id
        }
    }

    @ViewBuilder
    private var urlSourceInput: some View {
        if hasUploadedFiles {
            AgentUploadedFilesListView(
                files: uploadedFiles,
                onRemove: onRemoveUploadedFile,
                onAddMore: onUploadFiles
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                GrowingTextInputView(
                    text: bindingForFieldID("url"),
                    placeholder: "https://example.com",
                    minLines: 1,
                    maxLines: 3,
                    isEditable: true,
                    onShiftEnter: nil,
                    showsTextMetrics: true,
                    validationMessageProvider: nil
                )

                Button {
                    onUploadFiles()
                } label: {
                    Label("Upload Files", systemImage: "paperclip")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
