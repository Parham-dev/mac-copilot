export async function listModelCatalog(client) {
    if (!client) {
        throw new Error("Copilot client is not initialized");
    }
    if (typeof client.listModels !== "function") {
        throw new Error("Copilot SDK listModels is unavailable");
    }
    const raw = await client.listModels();
    if (!Array.isArray(raw)) {
        throw new Error("Copilot SDK listModels returned unsupported payload");
    }
    const models = raw
        .map((item) => {
        if (typeof item === "string") {
            return {
                id: item,
                name: item,
                capabilities: {
                    supports: { vision: false, reasoningEffort: false },
                    limits: { max_context_window_tokens: 0 },
                },
            };
        }
        if (item && typeof item === "object") {
            const id = typeof item.id === "string"
                ? item.id
                : (typeof item.model === "string" ? item.model : null);
            if (!id)
                return null;
            const supports = item.capabilities?.supports;
            const limits = item.capabilities?.limits;
            const policy = item.policy;
            const billing = item.billing;
            return {
                id,
                name: typeof item.name === "string" && item.name.length > 0 ? item.name : id,
                capabilities: {
                    supports: {
                        vision: Boolean(supports?.vision),
                        reasoningEffort: Boolean(supports?.reasoningEffort),
                    },
                    limits: {
                        ...(typeof limits?.max_prompt_tokens === "number" ? { max_prompt_tokens: limits.max_prompt_tokens } : {}),
                        max_context_window_tokens: typeof limits?.max_context_window_tokens === "number"
                            ? limits.max_context_window_tokens
                            : 0,
                    },
                },
                ...(policy && typeof policy === "object"
                    ? {
                        policy: {
                            state: typeof policy.state === "string" ? policy.state : "unconfigured",
                            terms: typeof policy.terms === "string" ? policy.terms : "",
                        },
                    }
                    : {}),
                ...(billing && typeof billing === "object" && typeof billing.multiplier === "number"
                    ? { billing: { multiplier: billing.multiplier } }
                    : {}),
                ...(typeof item.defaultReasoningEffort === "string"
                    ? { defaultReasoningEffort: item.defaultReasoningEffort }
                    : {}),
                ...(Array.isArray(item.supportedReasoningEfforts)
                    ? {
                        supportedReasoningEfforts: item.supportedReasoningEfforts
                            .filter((entry) => typeof entry === "string" && entry.length > 0),
                    }
                    : {}),
            };
        }
        return null;
    })
        .filter((value) => value && typeof value.id === "string" && value.id.length > 0);
    const uniqueByID = Array.from(new Map(models.map((model) => [model.id, model])).values());
    return uniqueByID;
}
