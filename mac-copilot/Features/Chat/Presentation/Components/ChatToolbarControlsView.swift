import SwiftUI

struct ChatToolbarControlsView: View {
    @Binding var selectedModel: String
    let availableModels: [String]
    let selectedModelInfoLabel: String
    @State private var showsModelPopover = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showsModelPopover.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selectedModel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsModelPopover, arrowEdge: .bottom) {
                modelPopoverContent
            }

            Text(selectedModelInfoLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var modelPopoverContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose model")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            Divider()

            ForEach(availableModels, id: \.self) { model in
                Button {
                    selectedModel = model
                    showsModelPopover = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedModel == model ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedModel == model ? .primary : .secondary)
                        Text(model)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .frame(minWidth: 260, alignment: .leading)
    }
}
