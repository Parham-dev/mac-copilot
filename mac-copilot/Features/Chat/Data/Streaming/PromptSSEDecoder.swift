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

        let decoded = try JSONDecoder().decode(PromptSSEPayload.self, from: data)
        return .payload(decoded)
    }
}

enum PromptSSEEventMapper {
    static func events(from payload: PromptSSEPayload) -> [PromptStreamEvent] {
        guard let kind = payload.type else {
            return []
        }

        switch kind {
        case "status":
            if let label = payload.label, !label.isEmpty {
                return [.status(label)]
            }
            return []
        case "tool_start":
            if let name = payload.toolName, !name.isEmpty {
                return [.status("Tool started: \(name)")]
            }
            return []
        case "tool_complete":
            if let name = payload.toolName, !name.isEmpty {
                let suffix = (payload.success == false) ? "failed" : "done"
                return [
                    .status("Tool \(suffix): \(name)"),
                    .toolExecution(
                        PromptToolExecutionEvent(
                            toolName: name,
                            success: payload.success != false,
                            details: payload.details,
                            input: payload.toolInput,
                            output: payload.toolOutput ?? payload.details
                        )
                    ),
                ]
            }
            return []
        case "done":
            return [.completed]
        default:
            return []
        }
    }
}

struct PromptSSEPayload: Decodable {
    let type: String?
    let text: String?
    let label: String?
    let toolName: String?
    let success: Bool?
    let details: String?
    let toolInput: String?
    let toolOutput: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case label
        case toolName
        case success
        case details
        case input
        case output
        case arguments
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        details = try container.decodeFlexibleString(forKey: .details)
        toolInput = try container.decodeFlexibleString(forKey: .input)
            ?? container.decodeFlexibleString(forKey: .arguments)
        toolOutput = try container.decodeFlexibleString(forKey: .output)
            ?? container.decodeFlexibleString(forKey: .result)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let jsonValue = try decodeIfPresent(PromptSSEJSONValue.self, forKey: key) {
            return jsonValue.rendered
        }

        return nil
    }
}

private enum PromptSSEJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: PromptSSEJSONValue])
    case array([PromptSSEJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: PromptSSEJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([PromptSSEJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                PromptSSEJSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    var rendered: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.formatted(.number)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            guard let data = try? JSONSerialization.data(withJSONObject: foundationObject, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return text
        case .null:
            return ""
        }
    }

    private var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let dictionary):
            return dictionary.mapValues { $0.foundationObject }
        case .array(let values):
            return values.map { $0.foundationObject }
        case .null:
            return NSNull()
        }
    }
}