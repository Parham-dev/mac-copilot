import Foundation

struct AgentDefinition: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String
    var allowedToolsDefault: [String]
    var inputSchema: AgentInputSchema
    var outputTemplate: AgentOutputTemplate
    var requiredConnections: [String]
    var optionalSkills: [AgentSkillRef]
    var customInstructions: String?
}

struct AgentInputSchema: Hashable, Codable {
    var fields: [AgentInputField]
}

struct AgentInputField: Hashable, Codable, Identifiable {
    enum FieldType: String, Codable {
        case url
        case text
        case select
    }

    let id: String
    var label: String
    var type: FieldType
    var required: Bool
    var options: [String]

    init(id: String, label: String, type: FieldType, required: Bool, options: [String] = []) {
        self.id = id
        self.label = label
        self.type = type
        self.required = required
        self.options = options
    }
}

struct AgentOutputTemplate: Hashable, Codable {
    var sectionOrder: [String]
}
