import AppKit
import Foundation
import SwiftUI
import Combine

@MainActor
final class AgentsDetailViewModel: ObservableObject {
    struct UploadedFile: Identifiable {
        let id: UUID
        let name: String
        let type: String
        let url: URL
        let sizeBytes: Int64
    }

    enum Tab: String, CaseIterable, Identifiable {
        case run = "Run"
        case history = "History"

        var id: String { rawValue }
    }

    @Published var formValues: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var latestRun: AgentRun?
    @Published var runActivity: String?
    @Published var selectedTab: Tab = .run
    @Published var selectedRunID: UUID?
    @Published var pendingDeleteRun: AgentRun?
    @Published var isAdvancedExpanded = false
    @Published var uploadedFiles: [UploadedFile] = []

    let advancedCitationModeFieldID = "advancedCitationMode"
    let advancedExtraContextFieldID = "advancedExtraContext"

    var activeAgentID: String?

    var primaryRunButtonTitle: String {
        if isRunning {
            return "Running..."
        }
        return "Run"
    }

    var uploadedFileItems: [AgentUploadedFileItem] {
        uploadedFiles.map { file in
            AgentUploadedFileItem(id: file.id, name: file.name, type: file.type)
        }
    }

    var hasUploadedFiles: Bool {
        !uploadedFiles.isEmpty
    }

    func selectedValue(for field: AgentInputField) -> String {
        formValues[field.id] ?? ""
    }

    func selectOption(_ option: String, for field: AgentInputField) {
        if option.caseInsensitiveCompare("other") == .orderedSame {
            if formValues[field.id]?.lowercased() != "other" {
                formValues[customValueKey(for: field.id)] = ""
            }
            formValues[field.id] = "other"
            return
        }

        formValues[field.id] = option
        formValues[customValueKey(for: field.id)] = ""
    }

    func isOtherSelected(for field: AgentInputField) -> Bool {
        selectedValue(for: field).lowercased() == "other"
    }

    func customValue(for field: AgentInputField) -> String {
        formValues[customValueKey(for: field.id)] ?? ""
    }

    func setCustomValue(_ value: String, for field: AgentInputField) {
        formValues[customValueKey(for: field.id)] = value
    }

}
