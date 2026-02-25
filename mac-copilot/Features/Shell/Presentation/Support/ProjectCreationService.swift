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
}