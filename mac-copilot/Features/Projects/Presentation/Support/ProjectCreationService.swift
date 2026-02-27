import Foundation
import AppKit

final class ProjectCreationService {
    struct CreatedProject {
        let name: String
        let localPath: String
    }

    func createProjectInteractively() throws -> CreatedProject? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = false
        panel.isExtensionHidden = true
        panel.nameFieldStringValue = "New Project"
        panel.title = "Create New Project"
        panel.prompt = "Create"
        panel.message = "Choose where the new project folder should be created."

        let response = panel.runModal()
        guard response == .OK, let targetURL = panel.url else {
            return nil
        }

        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        return CreatedProject(name: targetURL.lastPathComponent, localPath: targetURL.path)
    }

    func openProjectInteractively() throws -> CreatedProject? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Open Project"
        panel.prompt = "Open"
        panel.message = "Choose an existing project folder to add."

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return nil
        }

        return CreatedProject(name: selectedURL.lastPathComponent, localPath: selectedURL.path)
    }
}
