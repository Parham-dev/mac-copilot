import Foundation

struct SimpleHTMLRuntimeAdapter: ControlCenterRuntimeAdapter {
    let id: String = "simple-html"
    let displayName: String = "Simple HTML"
    private let utilities = ControlCenterRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.firstHTMLFile(in: root) != nil
    }

    func makePlan(project: ProjectRef) throws -> ControlCenterRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let htmlURL = utilities.firstHTMLFile(in: root) else {
            throw NSError(domain: "ControlCenter", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No HTML file found for Control Center."])
        }

        return ControlCenterRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .directOpen(target: htmlURL)
        )
    }
}

struct NodeRuntimeAdapter: ControlCenterRuntimeAdapter {
    let id: String = "node"
    let displayName: String = "Node"
    private let utilities = ControlCenterRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.fileExists("package.json", in: root)
    }

    func makePlan(project: ProjectRef) throws -> ControlCenterRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let npmExecutable = utilities.resolveExecutable(candidates: ["npm", "/opt/homebrew/bin/npm", "/usr/local/bin/npm"]) else {
            throw NSError(domain: "ControlCenter", code: 1005, userInfo: [NSLocalizedDescriptionKey: "npm was not found. Install Node.js and ensure npm is available."])
        }
        guard let nodeExecutable = utilities.resolveExecutable(candidates: ["node", "/opt/homebrew/bin/node", "/usr/local/bin/node"]) else {
            throw NSError(domain: "ControlCenter", code: 1006, userInfo: [NSLocalizedDescriptionKey: "node was not found. Install Node.js and ensure node is available."])
        }

        let packageJSONURL = root.appendingPathComponent("package.json")
        guard let json = utilities.readJSON(at: packageJSONURL) else {
            throw NSError(domain: "ControlCenter", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Could not parse package.json"])
        }

        let scripts = json["scripts"] as? [String: Any] ?? [:]
        let scriptName: String
        if scripts["dev"] != nil {
            scriptName = "dev"
        } else if scripts["start"] != nil {
            scriptName = "start"
        } else {
            throw NSError(domain: "ControlCenter", code: 1003, userInfo: [NSLocalizedDescriptionKey: "package.json has no dev/start script"])
        }

        let port = utilities.chooseOpenPort(preferred: [5173, 3000, 4173, 8080, 8000])
        var startArgs = ["run", scriptName]
        if scriptName == "dev" {
            startArgs.append(contentsOf: ["--", "--port", String(port)])
        }

        let installCommand: ControlCenterCommand?
        if !utilities.fileExists("node_modules", in: root) {
            installCommand = ControlCenterCommand(executable: npmExecutable, arguments: ["install"])
        } else {
            installCommand = nil
        }

        let runtimeEnvironment = makeNodeEnvironment(
            port: port,
            npmExecutable: npmExecutable,
            nodeExecutable: nodeExecutable
        )

        let healthURL = URL(string: "http://127.0.0.1:\(port)")!
        return ControlCenterRuntimePlan(
            adapterID: id,
            adapterName: displayName,
            workingDirectory: root,
            mode: .managedServer(
                install: installCommand,
                start: ControlCenterCommand(executable: npmExecutable, arguments: startArgs),
                healthCheckURL: healthURL,
                openURL: healthURL,
                bootTimeoutSeconds: 30,
                environment: runtimeEnvironment
            )
        )
    }

    private func makeNodeEnvironment(port: Int, npmExecutable: String, nodeExecutable: String) -> [String: String] {
        let npmBin = URL(fileURLWithPath: npmExecutable).deletingLastPathComponent().path
        let nodeBin = URL(fileURLWithPath: nodeExecutable).deletingLastPathComponent().path
        let existingPath = ProcessInfo.processInfo.environment["PATH"] ?? ""

        let seedPaths = [
            npmBin,
            nodeBin,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ] + existingPath.split(separator: ":").map(String.init)

        var seen = Set<String>()
        let merged = seedPaths.filter { segment in
            guard !segment.isEmpty else { return false }
            if seen.contains(segment) { return false }
            seen.insert(segment)
            return true
        }

        return [
            "PORT": String(port),
            "PATH": merged.joined(separator: ":")
        ]
    }
}

struct PythonRuntimeAdapter: ControlCenterRuntimeAdapter {
    let id: String = "python"
    let displayName: String = "Python"
    private let utilities = ControlCenterRuntimeUtilities()

    func canHandle(project: ProjectRef) -> Bool {
        let root = utilities.expandedProjectURL(for: project)
        return utilities.fileExists("requirements.txt", in: root)
            || utilities.fileExists("pyproject.toml", in: root)
            || utilities.fileExists("app.py", in: root)
    }

    func makePlan(project: ProjectRef) throws -> ControlCenterRuntimePlan {
        let root = utilities.expandedProjectURL(for: project)
        guard let pythonExecutable = utilities.resolveExecutable(candidates: ["python3", "python"]) else {
            throw NSError(domain: "ControlCenter", code: 1004, userInfo: [NSLocalizedDescriptionKey: "python3/python not found on PATH"])
        }

        let port = utilities.chooseOpenPort(preferred: [8000, 5000, 8080, 3000])
        let installCommand: ControlCenterCommand?

        if utilities.fileExists("requirements.txt", in: root) {
            installCommand = ControlCenterCommand(
                executable: pythonExecutable,
                arguments: ["-m", "pip", "install", "-r", "requirements.txt"]
            )
        } else {
            installCommand = nil
        }

        let startCommand: ControlCenterCommand
        if utilities.fileExists("manage.py", in: root) {
            startCommand = ControlCenterCommand(
                executable: pythonExecutable,
                arguments: ["manage.py", "runserver", "127.0.0.1:\(port)"]
            )
        } else if utilities.fileExists("app.py", in: root) {
            startCommand = ControlCenterCommand(
                executable: pythonExecutable,
                arguments: ["app.py"]
            )
        } else {
            startCommand = ControlCenterCommand(
                executable: pythonExecutable,
                arguments: ["-m", "http.server", String(port)]
            )
        }

        let url = URL(string: "http://127.0.0.1:\(port)")!
        return ControlCenterRuntimePlan(
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