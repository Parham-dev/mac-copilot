import { defineTool } from "@github/copilot-sdk";
export function buildCustomTools(args) {
    if (!args.executionContext) {
        return null;
    }
    const executionContextTool = defineTool("copilotforge_execution_context", {
        description: "Returns current CopilotForge execution context and policy metadata.",
        handler: async () => {
            return {
                chatKey: args.chatKey,
                workingDirectory: args.workingDirectory,
                executionContext: args.executionContext,
                policyProfile: args.policy.profileName,
                policyConfig: args.policy.config,
            };
        },
    });
    return [executionContextTool];
}
