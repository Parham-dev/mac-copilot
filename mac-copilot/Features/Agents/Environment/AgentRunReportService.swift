import Foundation

protocol AgentRunReportServing {
    @discardableResult
    func writeReport(
        definition: AgentDefinition,
        run: AgentRun,
        statuses: [String],
        toolEvents: [PromptToolExecutionEvent],
        usageEvents: [PromptUsageEvent],
        runDirectoryPath: String,
        thrownError: Error?
    ) -> URL?
}

struct AgentRunReportService: AgentRunReportServing {
    @discardableResult
    func writeReport(
        definition: AgentDefinition,
        run: AgentRun,
        statuses: [String],
        toolEvents: [PromptToolExecutionEvent],
        usageEvents: [PromptUsageEvent],
        runDirectoryPath: String,
        thrownError: Error?
    ) -> URL? {
        let runDirectoryURL = URL(fileURLWithPath: runDirectoryPath, isDirectory: true)
        let reportURL = runDirectoryURL.appendingPathComponent("run-report.html", isDirectory: false)
        let html = AgentRunReportHTMLBuilder.build(
            definition: definition,
            run: run,
            statuses: statuses,
            toolEvents: toolEvents,
            usageEvents: usageEvents,
            thrownError: thrownError
        )

        do {
            try html.write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
        } catch {
            NSLog(
                "[CopilotForge][AgentRunReport] failed to write report agentID=%@ runID=%@ path=%@ error=%@",
                definition.id,
                run.id.uuidString,
                reportURL.path,
                error.localizedDescription
            )
            return nil
        }
    }
}
