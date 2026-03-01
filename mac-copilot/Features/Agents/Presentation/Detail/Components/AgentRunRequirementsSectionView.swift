import SwiftUI

struct AgentRunRequirementsSectionView: View {
    let fields: [AgentInputField]
    let bindingForFieldID: (String) -> Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Requirements")
                .font(.headline)

            ForEach(fields, id: \.id) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label(for: field))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField(field.id, text: bindingForFieldID(field.id), axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func label(for field: AgentInputField) -> String {
        field.required ? "\(field.label) *" : field.label
    }
}
