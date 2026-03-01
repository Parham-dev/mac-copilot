import Foundation

@MainActor
final class BuiltInAgentDefinitionRepository: AgentDefinitionRepository {
    private let definitions: [AgentDefinition]

    init(definitions: [AgentDefinition]) {
        self.definitions = definitions
    }

    convenience init() {
        self.init(definitions: Self.defaultDefinitions)
    }

    func fetchDefinitions() -> [AgentDefinition] {
        definitions
    }

    func definition(id: String) -> AgentDefinition? {
        definitions.first(where: { $0.id == id })
    }
}

private extension BuiltInAgentDefinitionRepository {
    static var defaultDefinitions: [AgentDefinition] {
        [
            AgentDefinition(
                id: "content-summariser",
                name: "Content Summariser",
                description: "Summarise URLs, files, or pasted text into structured, decision-ready output.",
                allowedToolsDefault: ["fetch", "web_fetch", "fetch_webpage"],
                inputSchema: AgentInputSchema(fields: [
                    AgentInputField(id: "url", label: "URL", type: .url, required: true),
                    AgentInputField(id: "goal", label: "Goal", type: .select, required: false, options: ["summary", "key takeaways", "action items", "compare"]),
                    AgentInputField(id: "audience", label: "Audience", type: .select, required: false, options: ["general", "founder", "engineer", "marketer"]),
                    AgentInputField(id: "tone", label: "Tone", type: .select, required: false, options: ["neutral", "concise", "executive"]),
                    AgentInputField(id: "length", label: "Length", type: .select, required: false, options: ["short", "medium", "long"]),
                    AgentInputField(id: "outputFormat", label: "Output Format", type: .select, required: false, options: ["markdown", "text", "json"])
                ]),
                outputTemplate: AgentOutputTemplate(sectionOrder: [
                    "TL;DR",
                    "Key Points",
                    "Risks / Unknowns",
                    "Suggested Next Actions",
                    "Source Metadata"
                ]),
                requiredConnections: [],
                    optionalSkills: [
                        AgentSkillRef(
                            name: "agent-json-contract",
                            description: "Schema-safe JSON output contract and repair behavior.",
                            location: "skills/shared"
                        ),
                        AgentSkillRef(
                            name: "agent-tool-policy",
                            description: "Tool class policy, observability and fallback guardrails.",
                            location: "skills/shared"
                        )
                    ],
                customInstructions: nil
            )
        ]
    }
}
