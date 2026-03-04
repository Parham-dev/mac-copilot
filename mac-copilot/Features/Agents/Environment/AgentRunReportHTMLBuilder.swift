import Foundation

enum AgentRunReportHTMLBuilder {
    static func build(
        definition: AgentDefinition,
        run: AgentRun,
        statuses: [String],
        toolEvents: [PromptToolExecutionEvent],
        usageEvents: [PromptUsageEvent],
        thrownError: Error?
    ) -> String {
        let formatter = ISO8601DateFormatter()
        let startedAt = formatter.string(from: run.startedAt)
        let completedAt = run.completedAt.map { formatter.string(from: $0) } ?? "<not completed>"
        let durationSeconds = formattedDuration(startedAt: run.startedAt, completedAt: run.completedAt)

        let warningItems = listItems(run.diagnostics.warnings)
        let statusItems = listItems(statuses)
        let toolRows = toolEventRows(toolEvents)
        let usageRows = usageEventRows(usageEvents)
        let usageTotals = aggregateUsage(usageEvents)
        let traceBlocks = traceRows(run.diagnostics.toolTraces)
        let errorBlock = failureBlock(thrownError)
        let runJSON = runJSONString(run)
        let inputJSON = prettyJSONString(run.inputPayload)
        let finalOutput = htmlEscaped(run.finalOutput ?? run.streamedOutput ?? "")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>CopilotForge Run Report</title>
          <script src="https://cdn.tailwindcss.com"></script>
          <style>body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif; }</style>
        </head>
        <body class="bg-slate-100 text-slate-900">
          <main class="max-w-7xl mx-auto p-6 space-y-6">
            <header class="rounded-2xl bg-white border border-slate-200 p-5 shadow-sm">
              <p class="text-sm uppercase tracking-wide text-slate-500">CopilotForge Agent Run Report</p>
              <h1 class="text-2xl font-bold mt-1">\(htmlEscaped(definition.name))</h1>
              <p class="text-sm text-slate-600 mt-1">Run ID: <code>\(run.id.uuidString)</code></p>
            </header>

            <section class="grid grid-cols-1 md:grid-cols-4 gap-4">
              \(metricCard("Status", htmlEscaped(run.status.rawValue)))
              \(metricCard("Started", htmlEscaped(startedAt)))
              \(metricCard("Completed", htmlEscaped(completedAt)))
              \(metricCard("Duration", htmlEscaped(durationSeconds)))
            </section>

            <section class="grid grid-cols-1 md:grid-cols-4 gap-4">
              \(metricCard("🔢 Usage Events", "\(usageEvents.count)"))
              \(metricCard("🧠 Total Tokens", usageTotals.totalTokens))
              \(metricCard("💵 Total Cost", usageTotals.totalCost))
              \(metricCard("⏱ Total Duration", usageTotals.totalDurationMs))
            </section>

            \(errorBlock)

            <section class="rounded-xl bg-white border border-slate-200 p-4">
              <h2 class="text-lg font-semibold">Important Signals</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
                <div>
                  <p class="text-sm font-medium text-slate-700">Warnings</p>
                  <ul class="list-disc pl-5 mt-1 text-sm text-slate-700">\(warningItems)</ul>
                </div>
                <div>
                  <p class="text-sm font-medium text-slate-700">Status Timeline</p>
                  <ul class="list-disc pl-5 mt-1 text-sm text-slate-700">\(statusItems)</ul>
                </div>
              </div>
            </section>

            <section class="rounded-xl bg-white border border-slate-200 p-4 overflow-x-auto">
              <h2 class="text-lg font-semibold">Tool Activity</h2>
              \(tableShell(headers: ["#", "Tool", "Result", "Details", "Raw I/O"], rowsHTML: toolRows, emptyMessage: "No tool events recorded", colspan: 5))
            </section>

            <section class="rounded-xl bg-white border border-slate-200 p-4 overflow-x-auto">
              <h2 class="text-lg font-semibold">Token Usage (Per Call)</h2>
              \(tableShell(headers: ["#", "Model", "Input", "Output", "Total", "Cache Read", "Cache Write", "Cost", "Duration (ms)", "Raw"], rowsHTML: usageRows, emptyMessage: "No usage events recorded", colspan: 10))
            </section>

            <section class="rounded-xl bg-white border border-slate-200 p-4">
              <h2 class="text-lg font-semibold">Output</h2>
              <pre class="mt-3 bg-slate-950 text-slate-100 text-xs rounded-lg p-3 overflow-x-auto whitespace-pre-wrap">\(finalOutput.isEmpty ? "&lt;empty&gt;" : finalOutput)</pre>
            </section>

            <section class="rounded-xl bg-white border border-slate-200 p-4">
              <h2 class="text-lg font-semibold">Raw Debug</h2>
              <details class="mt-3"><summary class="cursor-pointer text-slate-700">Input Payload (JSON)</summary><pre class="mt-2 bg-slate-950 text-slate-100 text-xs rounded p-3 overflow-x-auto">\(htmlEscaped(inputJSON))</pre></details>
              <details class="mt-3"><summary class="cursor-pointer text-slate-700">Run Object (JSON)</summary><pre class="mt-2 bg-slate-950 text-slate-100 text-xs rounded p-3 overflow-x-auto">\(htmlEscaped(runJSON))</pre></details>
              <details class="mt-3" open><summary class="cursor-pointer text-slate-700">Diagnostic Tool Traces</summary><ul class="mt-2 text-sm text-slate-700">\(traceBlocks)</ul></details>
            </section>
          </main>
        </body>
        </html>
        """
    }

    private static func metricCard(_ title: String, _ value: String) -> String {
        """
        <article class=\"rounded-xl bg-white border border-slate-200 p-4\">
          <p class=\"text-xs uppercase tracking-wide text-slate-500\">\(title)</p>
          <p class=\"text-lg font-semibold mt-1\">\(value)</p>
        </article>
        """
    }

    private static func listItems(_ values: [String]) -> String {
        let rendered = values.map { "<li>\(htmlEscaped($0))</li>" }.joined()
        return rendered.isEmpty ? "<li class=\"text-slate-400\">none</li>" : rendered
    }

    private static func formattedDuration(startedAt: Date, completedAt: Date?) -> String {
        guard let completedAt else { return "<unknown>" }
        return String(format: "%.2f s", completedAt.timeIntervalSince(startedAt))
    }

    private static func tableShell(headers: [String], rowsHTML: String, emptyMessage: String, colspan: Int) -> String {
        let headersHTML = headers.map { "<th class=\"px-3 py-2\">\($0)</th>" }.joined()
        let body = rowsHTML.isEmpty
            ? "<tr><td colspan=\"\(colspan)\" class=\"px-3 py-4 text-slate-400\">\(emptyMessage)</td></tr>"
            : rowsHTML

        return """
        <table class=\"w-full mt-3 text-sm border-collapse\">
          <thead><tr class=\"border-b border-slate-300 text-left text-slate-600\">\(headersHTML)</tr></thead>
          <tbody>\(body)</tbody>
        </table>
        """
    }

    private static func toolEventRows(_ toolEvents: [PromptToolExecutionEvent]) -> String {
        toolEvents.enumerated().map { index, event in
            let successClass = event.success ? "text-emerald-700" : "text-rose-700"
            let successLabel = event.success ? "success" : "failed"
            let details = htmlEscaped(event.details ?? "")
            let input = htmlEscaped(event.input ?? "")
            let output = htmlEscaped(event.output ?? "")

            return """
            <tr class=\"border-b border-slate-200 align-top\">
              <td class=\"px-3 py-2 text-slate-500\">\(index + 1)</td>
              <td class=\"px-3 py-2 font-medium text-slate-900\">\(htmlEscaped(event.toolName))</td>
              <td class=\"px-3 py-2 \(successClass)\">\(successLabel)</td>
              <td class=\"px-3 py-2 text-slate-700\">\(details.isEmpty ? "<span class=\"text-slate-400\">&lt;none&gt;</span>" : details)</td>
              <td class=\"px-3 py-2\"><details><summary class=\"cursor-pointer text-slate-600\">input/output</summary><div class=\"mt-2 space-y-2\"><div><p class=\"text-xs uppercase tracking-wide text-slate-500\">Input</p><pre class=\"bg-slate-950 text-slate-100 text-xs rounded p-2 overflow-x-auto\">\(input.isEmpty ? "&lt;none&gt;" : input)</pre></div><div><p class=\"text-xs uppercase tracking-wide text-slate-500\">Output</p><pre class=\"bg-slate-950 text-slate-100 text-xs rounded p-2 overflow-x-auto\">\(output.isEmpty ? "&lt;none&gt;" : output)</pre></div></div></details></td>
            </tr>
            """
        }.joined(separator: "\n")
    }

    private static func usageEventRows(_ usageEvents: [PromptUsageEvent]) -> String {
        usageEvents.enumerated().map { index, usage in
            let input = usage.inputTokens.map(String.init) ?? "-"
            let output = usage.outputTokens.map(String.init) ?? "-"
            let total = usage.totalTokens.map(String.init) ?? "-"
            let cacheRead = usage.cacheReadTokens.map(String.init) ?? "-"
            let cacheWrite = usage.cacheWriteTokens.map(String.init) ?? "-"
            let cost = usage.cost.map { String(format: "%.4f", $0) } ?? "-"
            let duration = usage.durationMs.map { String(format: "%.0f", $0) } ?? "-"
            let model = htmlEscaped(usage.model ?? "-")
            let raw = htmlEscaped(usage.raw ?? "")

            return """
            <tr class=\"border-b border-slate-200 align-top\">
              <td class=\"px-3 py-2 text-slate-500\">\(index + 1)</td>
              <td class=\"px-3 py-2\">\(model)</td>
              <td class=\"px-3 py-2\">\(input)</td>
              <td class=\"px-3 py-2\">\(output)</td>
              <td class=\"px-3 py-2 font-medium\">\(total)</td>
              <td class=\"px-3 py-2\">\(cacheRead)</td>
              <td class=\"px-3 py-2\">\(cacheWrite)</td>
              <td class=\"px-3 py-2\">\(cost)</td>
              <td class=\"px-3 py-2\">\(duration)</td>
              <td class=\"px-3 py-2\"><details><summary class=\"cursor-pointer text-slate-600\">raw</summary><pre class=\"mt-2 bg-slate-950 text-slate-100 text-xs rounded p-2 overflow-x-auto\">\(raw.isEmpty ? "&lt;none&gt;" : raw)</pre></details></td>
            </tr>
            """
        }.joined(separator: "\n")
    }

    private static func traceRows(_ traces: [String]) -> String {
        let rows = traces.enumerated().map { index, trace in
            "<li class=\"mb-2\"><span class=\"text-slate-400 mr-2\">#\(index + 1)</span><code class=\"text-xs\">\(htmlEscaped(trace))</code></li>"
        }.joined()

        return rows.isEmpty ? "<li class=\"text-slate-400\">none</li>" : rows
    }

    private static func failureBlock(_ thrownError: Error?) -> String {
        guard let thrownError else { return "" }

        return """
        <section class=\"rounded-xl border border-rose-200 bg-rose-50 p-4\">
          <h2 class=\"text-lg font-semibold text-rose-800\">Failure Error</h2>
          <pre class=\"mt-2 text-xs text-rose-900 whitespace-pre-wrap\">\(htmlEscaped(thrownError.localizedDescription))</pre>
        </section>
        """
    }

    private static func aggregateUsage(_ usageEvents: [PromptUsageEvent]) -> (totalTokens: String, totalCost: String, totalDurationMs: String) {
        let tokenSum = usageEvents.compactMap(\.totalTokens).reduce(0, +)
        let costSum = usageEvents.compactMap(\.cost).reduce(0.0, +)
        let durationSum = usageEvents.compactMap(\.durationMs).reduce(0.0, +)

        return (
            totalTokens: tokenSum == 0 ? "-" : "\(tokenSum)",
            totalCost: costSum == 0 ? "-" : String(format: "%.4f", costSum),
            totalDurationMs: durationSum == 0 ? "-" : String(format: "%.0f ms", durationSum)
        )
    }

    private static func runJSONString(_ run: AgentRun) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(run),
              let value = String(data: data, encoding: .utf8)
        else {
            return "<unavailable>"
        }

        return value
    }

    private static func prettyJSONString(_ value: [String: String]) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "<unavailable>"
        }

        return text
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
