import Foundation

enum UserFacingErrorMapper {
    static func message(_ error: Error, fallback: String) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return fallback
        }

        if message.hasPrefix("The operation couldn’t be completed")
            || message.hasPrefix("The operation couldn't be completed")
            || message.contains("Error Domain=") {
            return fallback
        }

        return message
    }
}
