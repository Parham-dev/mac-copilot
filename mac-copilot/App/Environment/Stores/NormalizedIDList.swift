import Foundation

enum NormalizedIDList {
    static func from(_ ids: [String]) -> [String] {
        let trimmed = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(trimmed)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
