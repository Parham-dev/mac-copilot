import Foundation

enum PromptTrace {
    static let isEnabled: Bool = ProcessInfo.processInfo.environment["COPILOTFORGE_PROMPT_TRACE"] == "1"

    private static let protocolMarkerRegex = try? NSRegularExpression(
        pattern: "<\\s*\\/?\\s*(function_calls|system_notification|invoke|parameter)\\b[^>]*>",
        options: [.caseInsensitive]
    )

    static func containsProtocolMarker(in text: String) -> Bool {
        guard isEnabled, let regex = protocolMarkerRegex else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
