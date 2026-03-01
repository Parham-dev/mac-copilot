import SwiftUI

struct AgentRunAdvancedSectionView: View {
    @Binding var isExpanded: Bool
    let fields: [AgentInputField]
    let selectedValue: (AgentInputField) -> String
    let onSelectOption: (AgentInputField, String) -> Void
    let isOtherSelected: (AgentInputField) -> Bool
    let customValueBinding: (AgentInputField) -> Binding<String>
    @Binding var extraContext: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(fields, id: \.id) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(label(for: field))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(options(for: field), id: \.self) { option in
                                        Button {
                                            onSelectOption(field, option)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: isSelected(option: option, field: field) ? "largecircle.fill.circle" : "circle")
                                                    .font(.caption)
                                                Text(option)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(isSelected(option: option, field: field) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if isOtherSelected(field) {
                                GrowingTextInputView(
                                    text: customValueBinding(field),
                                    placeholder: "Type custom \(field.label.lowercased())",
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extra Context")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        GrowingTextInputView(
                            text: $extraContext,
                            placeholder: "Optional extra context for this run",
                            minLines: 2,
                            maxLines: 6,
                            isEditable: true,
                            onShiftEnter: nil,
                            showsTextMetrics: true,
                            validationMessageProvider: nil
                        )
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 6) {
                    Text("Advanced")
                        .font(.headline)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func label(for field: AgentInputField) -> String {
        field.required ? "\(field.label) *" : field.label
    }

    private func options(for field: AgentInputField) -> [String] {
        let hasOther = field.options.contains { $0.caseInsensitiveCompare("other") == .orderedSame }
        return hasOther ? field.options : (field.options + ["Other"])
    }

    private func isSelected(option: String, field: AgentInputField) -> Bool {
        let selected = selectedValue(field)
        if option.caseInsensitiveCompare("other") == .orderedSame {
            return selected.caseInsensitiveCompare("other") == .orderedSame
        }
        return selected.caseInsensitiveCompare(option) == .orderedSame
    }
}
