import Foundation

struct SimpleHTMLRuntimeAdapter: PreviewRuntimeAdapter {
    let id: String = "simple-html"
    let displayName: String = "Simple HTML"
    private let utilities = PreviewRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.firstHTMLFile(in: root) != nil
    }

    func makePlan(project: ProjectRef) throws -> PreviewRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let htmlURL = utilities.firstHTMLFile(in: root) else {
            throw NSError(domain: "Preview", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No HTML file found for simple HTML preview."])
        }

        return PreviewRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .directOpen(target: htmlURL)
        )
    }
}

struct NodeRuntimeAdapter: PreviewRuntimeAdapter {
    let id: String = "node"
    let displayName: String = "Node"
    private let utilities = PreviewRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.fileExists("package.json", in: root)
    }

    func makePlan(project: ProjectRef) throws -> PreviewRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        let packageJSONURL = root.appendingPathComponent("package.json")
        guard let json = utilities.readJSON(at: packageJSONURL) else {
            throw NSError(domain: "Preview", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Could not parse package.json"])
        }

        let scripts = json["scripts"] as? [String: Any] ?? [:]
        let scriptName: String
        if scripts["dev"] != nil {
            scriptName = "dev"
        } else if scripts["start"] != nil {
            scriptName = "start"
        } else {
            throw NSError(domain: "Preview", code: 1003, userInfo: [NSLocalizedDescriptionKey: "package.json has no dev/start script"])
        }

        let port = utilities.chooseOpenPort(preferred: [5173, 3000, 4173, 8080, 8000])
        var startArgs = ["npm", "run", scriptName]
        if scriptName == "dev" {
            startArgs.append(contentsOf: ["--", "--port", String(port)])
        }

        let installCommand: PreviewCommand?
        if !utilities.fileExists("node_modules", in: root) {
            installCommand = PreviewCommand(executable: "/usr/bin/env", arguments: ["npm", "install"])
        } else {
            installCommand = nil
        }

        let healthURL = URL(string: "http://127.0.0.1:\(port)")!
        return PreviewRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .managedServer(
                install: installCommand,
                start: PreviewCommand(executable: "/usr/bin/env", arguments: startArgs),
                healthCheckURL: healthURL,
                openURL: healthURL,
                bootTimeoutSeconds: 30,
                environment: ["PORT": String(port)]
            )
        )
    }
}

struct PythonRuntimeAdapter: PreviewRuntimeAdapter {
    let id: String = "python"
    let displayName: String = "Python"
    private let utilities = PreviewRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.fileExists("requirements.txt", in: root)
            || utilities.fileExists("pyproject.toml", in: root)
            || utilities.fileExists("app.py", in: root)
    }

    func makePlan(project: ProjectRef) throws -> PreviewRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let pythonExecutable = utilities.resolveExecutable(candidates: ["python3", "python"]) else {
            throw NSError(domain: "Preview", code: 1004, userInfo: [NSLocalizedDescriptionKey: "python3/python not found on PATH"])
        }

        let port = utilities.chooseOpenPort(preferred: [8000, 5000, 8080, 3000])
        let installCommand: PreviewCommand?

        if utilities.fileExists("requirements.txt", in: root) {
            installCommand = PreviewCommand(
                executable: "/usr/bin/env",
                arguments: [pythonExecutable, "-m", "pip", "install", "-r", "requirements.txt"]
            )
        } else {
            installCommand = nil
        }

        let startCommand: PreviewCommand
        if utilities.fileExists("manage.py", in: root) {
            startCommand = PreviewCommand(
                executable: "/usr/bin/env",
                arguments: [pythonExecutable, "manage.py", "runserver", "127.0.0.1:\(port)"]
            )
        } else if utilities.fileExists("app.py", in: root) {
            startCommand = PreviewCommand(
                executable: "/usr/bin/env",
                arguments: [pythonExecutable, "app.py"]
            )
        } else {
            startCommand = PreviewCommand(
                executable: "/usr/bin/env",
                arguments: [pythonExecutable, "-m", "http.server", String(port)]
            )
        }

        let url = URL(string: "http://127.0.0.1:\(port)")!
        return PreviewRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .managedServer(
                install: installCommand,
                start: startCommand,
                healthCheckURL: url,
                openURL: url,
                bootTimeoutSeconds: 30,
                environment: ["PORT": String(port)]
            )
        )
    }
}