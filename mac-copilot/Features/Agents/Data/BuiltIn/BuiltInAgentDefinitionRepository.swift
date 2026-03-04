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
                    AgentInputField(id: "url", label: "URL", type: .url, required: false),
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
                            name: "content-summariser",
                            description: "Runtime guidance for mixed-source content summarisation.",
                            location: "skills/agents/content-summariser"
                        ),
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
            ),
            AgentDefinition(
                id: "project-health",
                name: "Project Health",
                description: "Analyze a local project path and produce a phase-0 health report with a composite score, key risks, and prioritized fixes.",
                allowedToolsDefault: ["shell", "bash", "read_file", "list_directory", "search_files", "search_codebase"],
                inputSchema: AgentInputSchema(fields: [
                    AgentInputField(id: "projectPath", label: "Project Path", type: .text, required: true),
                    AgentInputField(id: "runTests", label: "Run Tests", type: .select, required: false, options: ["no", "dry-run", "yes"]),
                    AgentInputField(id: "depth", label: "Depth", type: .select, required: false, options: ["quick", "standard", "deep"])
                ]),
                outputTemplate: AgentOutputTemplate(sectionOrder: [
                    "Score Card",
                    "Action Items",
                    "Quick Stats",
                    "Git Health",
                    "Code Hygiene",
                    "Documentation",
                    "Limitations"
                ]),
                requiredConnections: [],
                optionalSkills: [
                    AgentSkillRef(
                        name: "project-health",
                        description: "Runtime guidance for project health dashboard scoring and evidence-based findings.",
                        location: "skills/agents/project-health"
                    ),
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
                customInstructions: "Phase-0 scope only: prioritize quick stats, git health, code hygiene, and documentation checks. Return measurable evidence for every score."
            )
        ]
    }
}
