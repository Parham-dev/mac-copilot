import Foundation
@testable import mac_copilot

enum ChatMessageFixture {
    static func user(
        text: String = "Build a dashboard",
        id: UUID = UUID(),
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ChatMessage {
        ChatMessage(id: id, role: .user, text: text, createdAt: createdAt)
    }

    static func assistant(
        text: String = "Working on it.",
        statusChips: [String] = ["Queued", "Generating"],
        toolExecutions: [ChatMessage.ToolExecution] = [
            ChatMessage.ToolExecution(toolName: "run_in_terminal", success: true, details: "Executed npm install")
        ],
        id: UUID = UUID(),
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_010)
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            role: .assistant,
            text: text,
            metadata: .init(statusChips: statusChips, toolExecutions: toolExecutions),
            createdAt: createdAt
        )
    }
}

enum CopilotModelCatalogPayloadFixture {
    static func wrappedObjectsData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "ok": true,
            "models": [
                [
                    "id": "gpt-5",
                    "name": "GPT-5",
                    "capabilities": [
                        "supports": ["vision": true, "reasoningEffort": true],
                        "limits": ["max_prompt_tokens": 128000, "max_context_window_tokens": 128000]
                    ],
                    "billing": ["multiplier": 1.0]
                ],
                [
                    "id": "claude-opus-4",
                    "name": "Claude Opus 4",
                    "capabilities": [
                        "supports": ["vision": false, "reasoningEffort": false],
                        "limits": ["max_prompt_tokens": 64000, "max_context_window_tokens": 64000]
                    ]
                ]
            ]
        ])
    }

    static func wrappedStringListData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "ok": true,
            "models": ["gpt-5", "claude-opus-4"]
        ])
    }

    static func directStringListData() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["gpt-5", "claude-opus-4"])
    }
}

enum SidecarHealthSnapshotFixture {
    static func healthy(
        nodeVersion: String = "v25.5.0",
        nodeExecPath: String = "/opt/homebrew/bin/node",
        processStartedAtMs: Double = 1_708_000_000_000
    ) -> SidecarHealthSnapshot {
        SidecarHealthSnapshot(
            service: "copilotforge-sidecar",
            nodeVersion: nodeVersion,
            nodeExecPath: nodeExecPath,
            processStartedAtMs: processStartedAtMs
        )
    }

    static func missingMetadata() -> SidecarHealthSnapshot {
        SidecarHealthSnapshot(
            service: nil,
            nodeVersion: nil,
            nodeExecPath: nil,
            processStartedAtMs: nil
        )
    }
}
