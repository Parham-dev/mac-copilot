import SwiftUI

struct ChatToolbarControlsView: View {
    @Binding var selectedModel: String
    let availableModels: [String]

    var body: some View {
        HStack(spacing: 10) {
            Picker("Model", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 140)

            Text("Model")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
