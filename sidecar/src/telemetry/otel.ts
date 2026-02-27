type Primitive = string | number | boolean;
type Attributes = Record<string, Primitive | undefined>;

type OTelAPI = {
  trace: {
    getTracer: (name: string) => any;
    setSpan: (ctx: any, span: any) => any;
  };
  context: {
    active: () => any;
  };
  SpanStatusCode: {
    OK: number;
    ERROR: number;
  };
  SpanKind: {
    CLIENT: number;
  };
};

type ToolSpanState = {
  span: any;
  startedAtMs: number;
  toolName: string;
};

type PromptTelemetryArgs = {
  requestId: string;
  model?: string;
  chatId?: string;
};

type PromptTelemetry = {
  enabled: boolean;
  onToolStart: (toolName: string, toolCallId?: string) => void;
  onToolComplete: (toolName: string, success: boolean, details?: string, toolCallId?: string) => void;
  onUsage: (usagePayload: Record<string, unknown>) => void;
  fail: (error: unknown) => void;
  end: () => void;
};

const tracerName = "copilotforge.sidecar";

let otelAPICache: Promise<OTelAPI | null> | null = null;

function otelEnabled() {
  return String(process.env.COPILOTFORGE_OTEL_ENABLED ?? "") === "1";
}

function sanitizeAttributes(attributes: Attributes) {
  const sanitized: Record<string, Primitive> = {};
  for (const [key, value] of Object.entries(attributes)) {
    if (value !== undefined) {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

async function loadOTelAPI(): Promise<OTelAPI | null> {
  if (otelAPICache) {
    return otelAPICache;
  }

  otelAPICache = (async () => {
    try {
      const moduleValue = await import("@opentelemetry/api");
      return moduleValue as OTelAPI;
    } catch {
      console.warn("[CopilotForge][OTel] @opentelemetry/api not installed; telemetry disabled");
      return null;
    }
  })();

  return otelAPICache;
}

function noopTelemetry(): PromptTelemetry {
  return {
    enabled: false,
    onToolStart: () => {},
    onToolComplete: () => {},
    onUsage: () => {},
    fail: () => {},
    end: () => {},
  };
}

export async function startPromptTelemetry(args: PromptTelemetryArgs): Promise<PromptTelemetry> {
  if (!otelEnabled()) {
    return noopTelemetry();
  }

  const otel = await loadOTelAPI();
  if (!otel) {
    return noopTelemetry();
  }

  const tracer = otel.trace.getTracer(tracerName);
  const rootSpan = tracer.startSpan("invoke_agent sidecar", {
    kind: otel.SpanKind.CLIENT,
    attributes: sanitizeAttributes({
      "gen_ai.operation.name": "invoke_agent",
      "gen_ai.provider.name": "github.copilot",
      "gen_ai.agent.name": "copilotforge-sidecar",
      "gen_ai.request.model": args.model,
      "copilotforge.request.id": args.requestId,
      "copilotforge.chat.id": args.chatId,
    }),
  });

  const toolSpans = new Map<string, ToolSpanState>();
  let ended = false;

  const startChildToolSpan = (toolName: string, toolCallId?: string) => {
    const key = toolCallId && toolCallId.length > 0
      ? toolCallId
      : `${toolName}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

    const parentContext = otel.trace.setSpan(otel.context.active(), rootSpan);
    const childSpan = tracer.startSpan(`execute_tool ${toolName}`, {
      kind: otel.SpanKind.CLIENT,
      attributes: sanitizeAttributes({
        "gen_ai.operation.name": "execute_tool",
        "gen_ai.tool.name": toolName,
        "gen_ai.tool.call.id": key,
      }),
    }, parentContext);

    toolSpans.set(key, {
      span: childSpan,
      startedAtMs: Date.now(),
      toolName,
    });
  };

  const completeChildToolSpan = (toolName: string, success: boolean, details?: string, toolCallId?: string) => {
    const key = toolCallId && toolCallId.length > 0 ? toolCallId : undefined;
    let state = key ? toolSpans.get(key) : undefined;

    if (!state) {
      const fallback = Array.from(toolSpans.entries()).find(([, value]) => value.toolName === toolName);
      if (fallback) {
        state = fallback[1];
        toolSpans.delete(fallback[0]);
      }
    } else if (key) {
      toolSpans.delete(key);
    }

    if (!state) {
      return;
    }

    if (typeof details === "string" && details.length > 0) {
      state.span.setAttribute("gen_ai.tool.call.result", details.slice(0, 512));
    }

    state.span.setAttribute("copilotforge.tool.duration_ms", Date.now() - state.startedAtMs);

    if (!success) {
      state.span.setStatus({ code: otel.SpanStatusCode.ERROR, message: "Tool execution failed" });
      state.span.setAttribute("error.type", "tool_error");
    } else {
      state.span.setStatus({ code: otel.SpanStatusCode.OK });
    }

    state.span.end();
  };

  const telemetry: PromptTelemetry = {
    enabled: true,
    onToolStart: (toolName, toolCallId) => {
      startChildToolSpan(toolName, toolCallId);
    },
    onToolComplete: (toolName, success, details, toolCallId) => {
      completeChildToolSpan(toolName, success, details, toolCallId);
    },
    onUsage: (usagePayload) => {
      const inputTokens = toNumber(usagePayload.inputTokens);
      const outputTokens = toNumber(usagePayload.outputTokens);
      const totalTokens = toNumber(usagePayload.totalTokens);
      const model = toString(usagePayload.model);

      if (inputTokens !== undefined) {
        rootSpan.setAttribute("gen_ai.usage.input_tokens", inputTokens);
      }
      if (outputTokens !== undefined) {
        rootSpan.setAttribute("gen_ai.usage.output_tokens", outputTokens);
      }
      if (totalTokens !== undefined) {
        rootSpan.setAttribute("gen_ai.usage.total_tokens", totalTokens);
      }
      if (model) {
        rootSpan.setAttribute("gen_ai.response.model", model);
      }
    },
    fail: (error) => {
      rootSpan.setStatus({ code: otel.SpanStatusCode.ERROR, message: String(error) });
      rootSpan.setAttribute("error.type", "session_error");
      rootSpan.setAttribute("error.message", String(error));
    },
    end: () => {
      if (ended) {
        return;
      }
      ended = true;

      for (const state of toolSpans.values()) {
        state.span.setStatus({ code: otel.SpanStatusCode.ERROR, message: "Tool span ended before completion" });
        state.span.end();
      }
      toolSpans.clear();

      rootSpan.end();
    },
  };

  return telemetry;
}

function toNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function toString(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
}
