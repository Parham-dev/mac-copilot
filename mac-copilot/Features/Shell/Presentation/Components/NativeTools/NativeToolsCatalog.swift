import Foundation

struct NativeToolDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let group: String
}

enum NativeToolsCatalog {
    static let defaultAgentToolIDs: [String] = [
        "ask_questions",
        "manage_todo_list",
        "runSubagent",
    ]

    static let all: [NativeToolDefinition] = [
        NativeToolDefinition(id: "list_dir", title: "List Directory", summary: "Browse files and folders in the workspace.", group: "Workspace"),
        NativeToolDefinition(id: "file_search", title: "File Search", summary: "Find files by glob patterns.", group: "Workspace"),
        NativeToolDefinition(id: "grep_search", title: "Text Search", summary: "Search text or regex across project files.", group: "Workspace"),
        NativeToolDefinition(id: "read_file", title: "Read File", summary: "Read file contents by line range.", group: "Workspace"),
        NativeToolDefinition(id: "apply_patch", title: "Apply Patch", summary: "Edit files using structured patch operations.", group: "Workspace"),
        NativeToolDefinition(id: "create_file", title: "Create File", summary: "Create new files in the workspace.", group: "Workspace"),
        NativeToolDefinition(id: "create_directory", title: "Create Directory", summary: "Create folders recursively.", group: "Workspace"),
        NativeToolDefinition(id: "get_errors", title: "Diagnostics", summary: "Collect compiler and lint errors.", group: "Workspace"),

        NativeToolDefinition(id: "run_in_terminal", title: "Run Terminal Command", summary: "Execute shell commands in persistent terminals.", group: "Execution"),
        NativeToolDefinition(id: "get_terminal_output", title: "Terminal Output", summary: "Read output from background terminals.", group: "Execution"),
        NativeToolDefinition(id: "await_terminal", title: "Await Terminal", summary: "Wait for background command completion.", group: "Execution"),
        NativeToolDefinition(id: "kill_terminal", title: "Kill Terminal", summary: "Stop background terminal processes.", group: "Execution"),
        NativeToolDefinition(id: "create_and_run_task", title: "Run VS Code Task", summary: "Create and execute workspace tasks.", group: "Execution"),

        NativeToolDefinition(id: "configure_python_environment", title: "Configure Python Environment", summary: "Set active Python environment for workspace.", group: "Python"),
        NativeToolDefinition(id: "install_python_packages", title: "Install Python Packages", summary: "Install dependencies in chosen environment.", group: "Python"),
        NativeToolDefinition(id: "get_python_environment_details", title: "Python Environment Details", summary: "Inspect environment and installed packages.", group: "Python"),
        NativeToolDefinition(id: "get_python_executable_details", title: "Python Executable Details", summary: "Get fully-qualified Python execution command.", group: "Python"),
        NativeToolDefinition(id: "mcp_pylance_mcp_s_pylanceRunCodeSnippet", title: "Run Python Snippet", summary: "Execute Python code directly in workspace environment.", group: "Python"),

        NativeToolDefinition(id: "get_changed_files", title: "Git Changes", summary: "Inspect staged/unstaged repository changes.", group: "Source Control"),
        NativeToolDefinition(id: "list_code_usages", title: "Code Usages", summary: "Find references/usages for symbols.", group: "Source Control"),
        NativeToolDefinition(id: "semantic_search", title: "Semantic Search", summary: "Search code by meaning and intent.", group: "Source Control"),

        NativeToolDefinition(id: "fetch_webpage", title: "Fetch Webpage", summary: "Load and parse webpage content.", group: "Web"),
        NativeToolDefinition(id: "open_simple_browser", title: "Open Browser", summary: "Open URLs in VS Code simple browser.", group: "Web"),

        NativeToolDefinition(id: "edit_notebook_file", title: "Edit Notebook", summary: "Insert/edit/delete notebook cells.", group: "Notebook"),
        NativeToolDefinition(id: "run_notebook_cell", title: "Run Notebook Cell", summary: "Execute a notebook code cell.", group: "Notebook"),
        NativeToolDefinition(id: "copilot_getNotebookSummary", title: "Notebook Summary", summary: "Inspect notebook cell metadata quickly.", group: "Notebook"),

        NativeToolDefinition(id: "create_new_workspace", title: "Create Workspace", summary: "Scaffold complete new project/workspace setup.", group: "Project Setup"),
        NativeToolDefinition(id: "create_new_jupyter_notebook", title: "Create Jupyter Notebook", summary: "Generate a new notebook with starter content.", group: "Project Setup"),
        NativeToolDefinition(id: "get_project_setup_info", title: "Project Setup Info", summary: "Get framework-specific setup instructions.", group: "Project Setup"),

        NativeToolDefinition(id: "ask_questions", title: "Ask Clarifying Questions", summary: "Prompt for choices when requirements are ambiguous.", group: "Agent"),
        NativeToolDefinition(id: "manage_todo_list", title: "Todo Plan", summary: "Track progress and update execution plan.", group: "Agent"),
        NativeToolDefinition(id: "runSubagent", title: "Run Subagent", summary: "Delegate complex searches or multi-step work.", group: "Agent")
    ]
}
