type SessionHooksBuildArgs = {
  chatKey: string;
  workingDirectory: string | null;
  allowedTools: string[] | null;
  executionContext: AgentExecutionContext | null;
};

import {
  DEFAULT_MAX_STRING_VALUE_BYTES,
  DEFAULT_MAX_TOOL_ARGS_BYTES,
  DEFAULT_MAX_TOOL_RESULT_BYTES,
  describeResultSize,
  isAllowedToolName,
  normalizeToolName,
  readBlockedTools,
  readPositiveIntegerEnv,
  redactString,
  redactValue,
  safeJSONStringify,
  truncateString,
} from "./copilotSessionHookUtils.js";
import type { AgentExecutionContext } from "./agentToolPolicyRegistry.js";
import { classifyToolName, isToolClassAllowed, resolveToolPolicy } from "./agentToolPolicyRegistry.js";

export function buildSessionHooks(args: SessionHooksBuildArgs) {
  const maxToolArgsBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_TOOL_ARGS_BYTES", DEFAULT_MAX_TOOL_ARGS_BYTES);
  const maxToolResultBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_TOOL_RESULT_BYTES", DEFAULT_MAX_TOOL_RESULT_BYTES);
  const maxStringValueBytes = readPositiveIntegerEnv("COPILOTFORGE_MAX_STRING_VALUE_BYTES", DEFAULT_MAX_STRING_VALUE_BYTES);
  const blockedTools = readBlockedTools();
  const resolvedToolPolicy = resolveToolPolicy(args.executionContext);
  const allowedToolSet = args.allowedTools ? new Set(args.allowedTools) : null;
  const normalizedAllowedToolSet = allowedToolSet
    ? new Set(Array.from(allowedToolSet).map((toolName) => normalizeToolName(toolName)).filter((toolName) => toolName.length > 0))
    : null;

  return {
    onUserPromptSubmitted: async (input: any, invocation: any) => {
      const prompt = typeof input?.prompt === "string" ? input.prompt : "";
      console.log("[CopilotForge][Hooks] user_prompt_submitted", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        promptLength: prompt.length,
        cwd: input?.cwd,
      }));
      return null;
    },

    onSessionStart: async (input: any, invocation: any) => {
      console.log("[CopilotForge][Hooks] session_start", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        source: input?.source,
        cwd: input?.cwd,
        workingDirectory: args.workingDirectory,
      }));
      return null;
    },

    onSessionEnd: async (input: any, invocation: any) => {
      console.log("[CopilotForge][Hooks] session_end", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        reason: input?.reason,
        hasError: typeof input?.error === "string" && input.error.length > 0,
      }));
      return null;
    },

    onPreToolUse: async (input: any, invocation: any) => {
      const toolName = typeof input?.toolName === "string" ? input.toolName : "";
      const toolClass = classifyToolName(toolName);
      const toolArgs = input?.toolArgs;
      const serializedArgs = safeJSONStringify(toolArgs);

      if (!toolName) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          tool_class: "unknown",
          decision: "deny",
          reason: "missing_tool_name",
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: "Tool call denied: missing tool name.",
        };
      }

      if (!isToolClassAllowed(resolvedToolPolicy, toolClass)) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          toolClass,
          tool_class: toolClass,
          toolName,
          decision: "deny",
          reason: "blocked_by_policy_profile",
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: `Tool '${toolName}' (${toolClass}) is not allowed by policy profile '${resolvedToolPolicy.profileName}'.`,
        };
      }

      if (blockedTools.has(toolName)) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          toolClass,
          tool_class: toolClass,
          decision: "deny",
          toolName,
          reason: "blocked_by_policy",
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: `Tool '${toolName}' is blocked by sidecar policy.`,
        };
      }

      if (allowedToolSet
          && normalizedAllowedToolSet
          && !isAllowedToolName(toolName, allowedToolSet, normalizedAllowedToolSet)) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          toolClass,
          tool_class: toolClass,
          decision: "deny",
          toolName,
          reason: "not_in_allowed_list",
          allowedToolsCount: allowedToolSet.size,
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: `Tool '${toolName}' is not in the allowed tool list for this chat context.`,
        };
      }

      if (serializedArgs.length > maxToolArgsBytes) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          toolClass,
          tool_class: toolClass,
          decision: "deny",
          toolName,
          reason: "args_too_large",
          argsBytes: serializedArgs.length,
          maxToolArgsBytes,
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: `Tool '${toolName}' arguments exceed the configured size limit (${maxToolArgsBytes} bytes).`,
        };
      }

      if (typeof toolArgs?.command === "string" && toolArgs.command.length > maxStringValueBytes) {
        console.warn("[CopilotForge][Hooks] tool_denied", JSON.stringify({
          sessionId: invocation?.sessionId,
          chatKey: args.chatKey,
          executionContext: args.executionContext,
          policyProfile: resolvedToolPolicy.profileName,
          policy_profile: resolvedToolPolicy.profileName,
          toolClass,
          tool_class: toolClass,
          decision: "deny",
          toolName,
          reason: "command_too_large",
          commandLength: toolArgs.command.length,
          maxStringValueBytes,
        }));
        return {
          permissionDecision: "deny",
          permissionDecisionReason: `Tool '${toolName}' command exceeds the configured size limit (${maxStringValueBytes} chars).`,
        };
      }

      console.log("[CopilotForge][Hooks] pre_tool_use", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        policy_profile: resolvedToolPolicy.profileName,
        toolClass,
        tool_class: toolClass,
        decision: "allow",
        toolName,
        argsBytes: serializedArgs.length,
      }));

      return {
        permissionDecision: "allow",
      };
    },

    onPostToolUse: async (input: any, invocation: any) => {
      const toolName = typeof input?.toolName === "string" ? input.toolName : "unknown";
      const toolClass = classifyToolName(toolName);
      const rawResult = input?.toolResult;
      const redactedResult = redactValue(rawResult);
      const size = describeResultSize(redactedResult);

      console.log("[CopilotForge][Hooks] post_tool_use", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        policy_profile: resolvedToolPolicy.profileName,
        toolClass,
        tool_class: toolClass,
        decision: "post_tool_use",
        toolName,
        resultBytes: size.bytes,
        resultPreview: size.preview,
      }));

      if (size.bytes <= maxToolResultBytes) {
        if (safeJSONStringify(rawResult) !== safeJSONStringify(redactedResult)) {
          return { modifiedResult: redactedResult };
        }
        return null;
      }

      const compact = {
        truncated: true,
        originalBytes: size.bytes,
        maxBytes: maxToolResultBytes,
        preview: truncateString(size.preview, maxToolResultBytes),
      };

      return {
        modifiedResult: compact,
        additionalContext: `Tool result was truncated from ${size.bytes} bytes to enforce output size limits.`,
      };
    },

    onErrorOccurred: async (input: any, invocation: any) => {
      console.error("[CopilotForge][Hooks] error_occurred", JSON.stringify({
        sessionId: invocation?.sessionId,
        chatKey: args.chatKey,
        executionContext: args.executionContext,
        policyProfile: resolvedToolPolicy.profileName,
        policy_profile: resolvedToolPolicy.profileName,
        decision: "error",
        context: input?.errorContext,
        recoverable: input?.recoverable,
        error: redactString(String(input?.error ?? "unknown error")),
      }));
      return null;
    },
  };
}
