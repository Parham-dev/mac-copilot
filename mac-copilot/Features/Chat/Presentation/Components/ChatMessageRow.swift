import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble(color: .gray.opacity(0.18), alignment: .leading)
                Spacer(minLength: 36)
            } else {
                Spacer(minLength: 36)
                bubble(color: .accentColor.opacity(0.2), alignment: .trailing)
            }
        }
    }

    private func bubble(color: Color, alignment: Alignment) -> some View {
        Text(message.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 700, alignment: alignment)
    }
}
