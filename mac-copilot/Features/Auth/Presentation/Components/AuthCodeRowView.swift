import SwiftUI
import AppKit

struct AuthCodeRowView: View {
    let userCode: String

    var body: some View {
        HStack(spacing: 10) {
            Text("Enter this code on GitHub: \(userCode)")
                .font(.headline)

            Button("Copy Code") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(userCode, forType: .string)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
