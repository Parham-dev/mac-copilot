import Foundation

final class SidecarRuntimeTimestampProvider {
    func latestRuntimeUpdatedAtMs(referenceScriptURL: URL) -> Double {
        let fileManager = FileManager.default
        let scriptPath = referenceScriptURL.path
        var newestDate = modificationDate(forPath: scriptPath, fileManager: fileManager) ?? .distantPast

        let distDirectoryURL = referenceScriptURL.deletingLastPathComponent()
        if let enumerator = fileManager.enumerator(at: distDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for case let fileURL as URL in enumerator {
                let candidateDate = modificationDate(forPath: fileURL.path, fileManager: fileManager)
                if let candidateDate, candidateDate > newestDate {
                    newestDate = candidateDate
                }
            }
        }

        return newestDate.timeIntervalSince1970 * 1000
    }

    private func modificationDate(forPath path: String, fileManager: FileManager) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }

        return attributes[.modificationDate] as? Date
    }
}
