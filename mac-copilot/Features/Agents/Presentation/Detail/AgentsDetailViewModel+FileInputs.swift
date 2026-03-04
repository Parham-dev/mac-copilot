import AppKit
import Foundation

extension AgentsDetailViewModel {
    func addUploadedFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else {
            return
        }

        var newlyAdded: [UploadedFile] = []
        var failedFiles: [String] = []

        for url in panel.urls {
            if uploadedFiles.contains(where: { $0.url == url }) {
                continue
            }

            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile ?? true else {
                    failedFiles.append(url.lastPathComponent)
                    continue
                }

                let type = fileType(for: url)
                let file = UploadedFile(
                    id: UUID(),
                    name: url.lastPathComponent,
                    type: type,
                    url: url,
                    sizeBytes: Int64(values.fileSize ?? 0)
                )
                newlyAdded.append(file)
            } catch {
                failedFiles.append(url.lastPathComponent)
            }
        }

        uploadedFiles.append(contentsOf: newlyAdded)

        if !failedFiles.isEmpty {
            errorMessage = "Some files could not be loaded: \(failedFiles.joined(separator: ", "))"
        }
    }

    func pickProjectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.title = "Open Project Folder"
        panel.message = "Choose the local project folder to analyze."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        formValues["projectPath"] = selectedURL.path
        errorMessage = nil
    }

    func removeUploadedFile(id: UUID) {
        uploadedFiles.removeAll { $0.id == id }
    }

    private func fileType(for url: URL) -> String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ext.isEmpty ? "file" : ext
    }
}
