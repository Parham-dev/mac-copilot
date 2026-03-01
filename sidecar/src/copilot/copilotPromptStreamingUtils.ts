export function normalizeUsagePayload(data: unknown): Record<string, unknown> | null {
  if (!data || typeof data !== "object") {
    return null;
  }

  const source = data as Record<string, unknown>;
  const usageRoot = source.usage && typeof source.usage === "object"
    ? (source.usage as Record<string, unknown>)
    : source;

  const inputTokens = readTokenNumber(usageRoot, ["inputTokens", "input_tokens", "promptTokens", "prompt_tokens"]);
  const outputTokens = readTokenNumber(usageRoot, ["outputTokens", "output_tokens", "completionTokens", "completion_tokens"]);
  const totalTokens = readTokenNumber(usageRoot, ["totalTokens", "total_tokens"])
    ?? sumTokens(inputTokens, outputTokens);

  const model = readStringValue(usageRoot, ["model"]) ?? readStringValue(source, ["model"]);

  const usage: Record<string, unknown> = {
    inputTokens,
    outputTokens,
    totalTokens,
    raw: usageRoot,
  };

  if (model) {
    usage.model = model;
  }

  return usage;
}

function readTokenNumber(source: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return undefined;
}

function readStringValue(source: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return undefined;
}

function sumTokens(inputTokens?: number, outputTokens?: number) {
  if (typeof inputTokens !== "number" && typeof outputTokens !== "number") {
    return undefined;
  }
  return (inputTokens ?? 0) + (outputTokens ?? 0);
}

export function mergeDeltaText(current: string, incoming: string): string {
  if (!incoming) {
    return current;
  }

  if (!current) {
    return incoming;
  }

  if (incoming === current) {
    return current;
  }

  if (incoming.startsWith(current)) {
    return incoming;
  }

  if (current.startsWith(incoming)) {
    return current;
  }

  const overlap = longestSuffixPrefixOverlap(current, incoming);
  if (overlap > 0) {
    return current + incoming.slice(overlap);
  }

  if (incoming.includes(current)) {
    return incoming;
  }

  if (current.includes(incoming)) {
    return current;
  }

  return current + incoming;
}

export function extractIncrementalDelta(previous: string, next: string): string {
  if (!next) {
    return "";
  }

  if (!previous) {
    return next;
  }

  if (next === previous) {
    return "";
  }

  if (next.startsWith(previous)) {
    return next.slice(previous.length);
  }

  if (previous.includes(next)) {
    return "";
  }

  return next;
}

function longestSuffixPrefixOverlap(lhs: string, rhs: string): number {
  const maxCandidate = Math.min(lhs.length, rhs.length);
  for (let length = maxCandidate; length >= 1; length -= 1) {
    if (lhs.slice(-length) === rhs.slice(0, length)) {
      return length;
    }
  }
  return 0;
}
