import Foundation

enum PromptSSELine {
    case done
    case payload(PromptSSEPayload)
}

enum PromptSSEDecoder {
    static func decode(line: String) throws -> PromptSSELine? {
        guard line.hasPrefix("data: ") else {
            return nil
        }

        let payload = String(line.dropFirst(6))
        if payload == "[DONE]" {
            return .done
        }

        guard let data = payload.data(using: .utf8) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(PromptSSEPayload.self, from: data)
            return .payload(decoded)
        } catch {
            if let recoveredUsage = PromptSSEUsageRecovery.recoverMalformedUsagePayload(from: payload) {
                return .payload(recoveredUsage)
            }
            throw error
        }
    }
}