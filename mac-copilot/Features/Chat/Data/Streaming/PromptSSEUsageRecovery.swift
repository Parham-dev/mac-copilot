import Foundation

enum PromptSSEUsageRecovery {
    static func recoverMalformedUsagePayload(from payload: String) -> PromptSSEPayload? {
        guard payload.contains("\"type\":\"usage\"") || payload.contains("\"type\": \"usage\"") else {
            return nil
        }

        return PromptSSEPayload(
            type: "usage",
            text: nil,
            label: nil,
            toolName: nil,
            success: nil,
            details: nil,
            toolInput: nil,
            toolOutput: nil,
            error: nil,
            inputTokens: extractInt("inputTokens", from: payload),
            outputTokens: extractInt("outputTokens", from: payload),
            totalTokens: extractInt("totalTokens", from: payload),
            cacheReadTokens: extractInt("cacheReadTokens", from: payload),
            cacheWriteTokens: extractInt("cacheWriteTokens", from: payload),
            cost: extractDouble("cost", from: payload),
            duration: extractDouble("duration", from: payload),
            model: extractString("model", from: payload),
            raw: nil
        )
    }

    private static func extractInt(_ key: String, from payload: String) -> Int? {
        guard let value = extractDouble(key, from: payload) else {
            return nil
        }
        return Int(value)
    }

    private static func extractDouble(_ key: String, from payload: String) -> Double? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\\\"\(escapedKey)\\\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: payload, range: NSRange(location: 0, length: payload.utf16.count)),
              let range = Range(match.range(at: 1), in: payload)
        else {
            return nil
        }

        return Double(payload[range])
    }

    private static func extractString(_ key: String, from payload: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\\\"\(escapedKey)\\\"\\s*:\\s*\\\"([^\\\"]*)\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: payload, range: NSRange(location: 0, length: payload.utf16.count)),
              let range = Range(match.range(at: 1), in: payload)
        else {
            return nil
        }

        return String(payload[range])
    }
}
