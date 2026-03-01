import { defineTool, type Tool } from "@github/copilot-sdk";
import type { AgentExecutionContext, ResolvedToolPolicy } from "./agentToolPolicyRegistry.js";

type BuildCustomToolsArgs = {
  chatKey: string;
  workingDirectory: string | null;
  executionContext: AgentExecutionContext | null;
  policy: ResolvedToolPolicy;
};

export function buildCustomTools(args: BuildCustomToolsArgs): Tool[] | null {
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
