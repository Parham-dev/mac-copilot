import Foundation

struct AgentRunResult: Hashable, Codable {
    struct SourceMetadata: Hashable, Codable {
        var url: String
        var title: String?
        var fetchedAt: String?
    }

    var tldr: String
    var keyPoints: [String]
    var risksUnknowns: [String]
    var suggestedNextActions: [String]
    var sourceMetadata: SourceMetadata
}

enum AgentRunResultParser {
    enum ParseError: LocalizedError {
        case invalidUTF8
        case jsonObjectNotFound
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidUTF8:
                return "Invalid UTF-8 payload"
            case .jsonObjectNotFound:
                return "Could not find JSON object in model output"
            case .decodeFailed(let details):
                return "JSON decode failed: \(details)"
            }
        }
    }

    static func parse(from text: String) -> AgentRunResult? {
        try? parseDetailed(from: text).get()
    }

    static func parseDetailed(from text: String) -> Result<AgentRunResult, ParseError> {
        guard text.data(using: .utf8) != nil else {
            return .failure(.invalidUTF8)
        }

        let decoder = JSONDecoder()

        if let directData = text.data(using: .utf8) {
            do {
                let result = try decoder.decode(AgentRunResult.self, from: directData)
                return .success(result)
            } catch {
            }
        }

        guard let extractedJSON = extractFirstJSONObject(from: text),
              let extractedData = extractedJSON.data(using: .utf8)
        else {
            return .failure(.jsonObjectNotFound)
        }

        do {
            let result = try decoder.decode(AgentRunResult.self, from: extractedData)
            return .success(result)
        } catch {
            return .failure(.decodeFailed(error.localizedDescription))
        }
    }

    static func encodePretty(_ result: AgentRunResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return string
    }

    private static func extractFirstJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        var index = start
        while index < text.endIndex {
            let char = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        let nextIndex = text.index(after: index)
                        return String(text[start..<nextIndex])
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
