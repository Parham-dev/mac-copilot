export type AgentExecutionContext = {
  agentID: string;
  feature: string;
  policyProfile: string;
  skillNames?: string[];
  requireSkills?: boolean;
};

export type ToolClass = "native" | "custom" | "mcp" | "unknown";

export type PolicyProfileConfig = {
  allowNative: boolean;
  allowCustom: boolean;
  allowMCP: boolean;
  strictFallback: boolean;
};

export type ResolvedToolPolicy = {
  profileName: string;
  config: PolicyProfileConfig;
  agentID: string | null;
  feature: string | null;
};

const POLICY_PROFILES: Record<string, PolicyProfileConfig> = {
  default: {
    allowNative: true,
    allowCustom: true,
    allowMCP: true,
    strictFallback: false,
  },
  "strict-fetch-mcp": {
    allowNative: false,
    allowCustom: true,
    allowMCP: true,
    strictFallback: true,
  },
};

const AGENT_DEFAULT_POLICY_PROFILE: Record<string, string> = {
  "url-summariser": "default",
};

function normalizeName(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

export function classifyToolName(toolName: string): ToolClass {
  const normalized = normalizeName(toolName);
  if (!normalized) {
    return "unknown";
  }

  if (normalized === "fetch" || normalized.startsWith("fetch_")) {
    return "mcp";
  }

  if (normalized.startsWith("copilotforge_") || normalized.startsWith("app_")) {
    return "custom";
  }

  return "native";
}

export function resolveToolPolicy(executionContext: AgentExecutionContext | null): ResolvedToolPolicy {
  const agentID = executionContext?.agentID?.trim() || null;
  const feature = executionContext?.feature?.trim() || null;
  const requestedProfile = executionContext?.policyProfile?.trim() || "";

  const fallbackProfile = agentID
    ? (AGENT_DEFAULT_POLICY_PROFILE[agentID] ?? "default")
    : "default";

  const profileName = POLICY_PROFILES[requestedProfile] ? requestedProfile : fallbackProfile;
  const config = POLICY_PROFILES[profileName] ?? POLICY_PROFILES.default;

  return {
    profileName,
    config,
    agentID,
    feature,
  };
}

export function isToolClassAllowed(policy: ResolvedToolPolicy, toolClass: ToolClass): boolean {
  if (toolClass === "unknown") {
    return true;
  }

  if (toolClass === "custom") {
    return policy.config.allowCustom;
  }

  if (toolClass === "mcp") {
    return policy.config.allowMCP;
  }

  if (toolClass === "native") {
    return policy.config.allowNative;
  }

  return true;
}

export function summarizeToolPath(toolClasses: Set<ToolClass>) {
  const toolPath = toolClasses.has("custom")
    ? "custom"
    : toolClasses.has("mcp")
      ? "mcp"
      : toolClasses.has("native")
        ? "native"
        : "none";

  const fallbackUsed = toolClasses.size > 1;

  return {
    toolPath,
    fallbackUsed,
  };
}