import SwiftUI

struct AgentRunModelSectionView: View {
    @Binding var selectedModelID: String
    let availableModels: [String]
    let isLoadingModels: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model")
                .font(.headline)

            Picker("Model", selection: $selectedModelID) {
                ForEach(availableModels, id: \.self) { modelID in
                    Text(modelID).tag(modelID)
                }
            }
            .pickerStyle(.menu)
            .disabled(isDisabled || isLoadingModels)

            if isLoadingModels {
                Text("Loading models…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
