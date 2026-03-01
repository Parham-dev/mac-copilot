import SwiftUI

struct AgentResultPanelView: View {
    let run: AgentRun
    let format: String
    let resultText: String?
    let resultFont: Font
    let onCopy: (String) -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.headline)

                Spacer()

                Text(format.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let resultText,
                   !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        onCopy(resultText)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onDownload()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let finalOutput = run.finalOutput,
               !finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(finalOutput)
                        .font(resultFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 140, maxHeight: 380)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let streamedOutput = run.streamedOutput,
                      !streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(streamedOutput)
                        .font(resultFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 140, maxHeight: 380)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("No output body was produced for this run. Check warnings and tool traces.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !run.diagnostics.warnings.isEmpty {
                Text("Warnings: \(run.diagnostics.warnings.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
