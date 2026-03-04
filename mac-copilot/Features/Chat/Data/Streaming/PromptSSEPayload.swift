import Foundation

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
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
    let cacheReadTokens: Int?
    let cacheWriteTokens: Int?
    let cost: Double?
    let duration: Double?
    let model: String?
    let raw: String?

    init(
        type: String?,
        text: String?,
        label: String?,
        toolName: String?,
        success: Bool?,
        details: String?,
        toolInput: String?,
        toolOutput: String?,
        error: String?,
        inputTokens: Int?,
        outputTokens: Int?,
        totalTokens: Int?,
        cacheReadTokens: Int?,
        cacheWriteTokens: Int?,
        cost: Double?,
        duration: Double?,
        model: String?,
        raw: String?
    ) {
        self.type = type
        self.text = text
        self.label = label
        self.toolName = toolName
        self.success = success
        self.details = details
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.error = error
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cost = cost
        self.duration = duration
        self.model = model
        self.raw = raw
    }

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
        case inputTokens
        case outputTokens
        case totalTokens
        case cacheReadTokens
        case cacheWriteTokens
        case cost
        case duration
        case model
        case raw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeFlexibleString(forKey: .type)
        text = try container.decodeFlexibleString(forKey: .text)
        label = try container.decodeFlexibleString(forKey: .label)
        toolName = try container.decodeFlexibleString(forKey: .toolName)
        success = try container.decodeFlexibleBool(forKey: .success)
        details = try container.decodeFlexibleString(forKey: .details)
        toolInput = try container.decodeFlexibleString(forKey: .input)
            ?? container.decodeFlexibleString(forKey: .arguments)
        toolOutput = try container.decodeFlexibleString(forKey: .output)
            ?? container.decodeFlexibleString(forKey: .result)
        error = try container.decodeFlexibleString(forKey: .error)
        inputTokens = try container.decodeFlexibleInt(forKey: .inputTokens)
        outputTokens = try container.decodeFlexibleInt(forKey: .outputTokens)
        totalTokens = try container.decodeFlexibleInt(forKey: .totalTokens)
        cacheReadTokens = try container.decodeFlexibleInt(forKey: .cacheReadTokens)
        cacheWriteTokens = try container.decodeFlexibleInt(forKey: .cacheWriteTokens)
        cost = try container.decodeFlexibleDouble(forKey: .cost)
        duration = try container.decodeFlexibleDouble(forKey: .duration)
        model = try container.decodeFlexibleString(forKey: .model)
        raw = try container.decodeFlexibleString(forKey: .raw)
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

    func decodeFlexibleBool(forKey key: Key) throws -> Bool? {
        if let boolValue = try decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        guard let stringValue = try decodeFlexibleString(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !stringValue.isEmpty
        else {
            return nil
        }

        if ["true", "1", "yes", "on", "success"].contains(stringValue) {
            return true
        }

        if ["false", "0", "no", "off", "failed", "failure"].contains(stringValue) {
            return false
        }

        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        guard let stringValue = try decodeFlexibleString(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !stringValue.isEmpty
        else {
            return nil
        }

        if let intValue = Int(stringValue) {
            return intValue
        }

        if let doubleValue = Double(stringValue) {
            return Int(doubleValue)
        }

        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        guard let stringValue = try decodeFlexibleString(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !stringValue.isEmpty
        else {
            return nil
        }

        return Double(stringValue)
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
