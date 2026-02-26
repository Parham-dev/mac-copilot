import Foundation

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
