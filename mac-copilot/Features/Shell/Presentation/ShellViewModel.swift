import Foundation
import SwiftUI
import Combine

/// Shell-level navigation state only.
///
/// The shell no longer owns any feature-specific data (projects, chats, etc.).
/// It tracks which feature is active (`activeFeatureID`) and the opaque
/// per-feature selection value (`selectionByFeature`).
///
/// Each feature receives a `Binding<AnyHashable?>` that reads/writes the
/// relevant entry in `selectionByFeature`.
@MainActor
final class ShellViewModel: ObservableObject {

    // MARK: - Published state

    /// The ID of the currently active feature (matches a `FeatureModule.id`).
    @Published var activeFeatureID: String?

    /// Opaque per-feature selection. Keyed by `FeatureModule.id`.
    @Published var selectionByFeature: [String: AnyHashable] = [:]

    // MARK: - Init

    init(defaultFeatureID: String? = nil) {
        self.activeFeatureID = defaultFeatureID
    }

    // MARK: - Accessors

    /// Returns the current selection for the given feature as an `AnyHashable?`.
    func selection(for featureID: String) -> AnyHashable? {
        selectionByFeature[featureID]
    }

    /// Builds a two-way `Binding<AnyHashable?>` for a given feature's selection.
    func selectionBinding(for featureID: String) -> Binding<AnyHashable?> {
        Binding(
            get: { [weak self] in self?.selectionByFeature[featureID] },
            set: { [weak self] newValue in
                guard let self else { return }
                if let newValue {
                    self.selectionByFeature[featureID] = newValue
                } else {
                    self.selectionByFeature.removeValue(forKey: featureID)
                }
                // Activating any feature item makes that feature active.
                self.activeFeatureID = featureID
            }
        )
    }

    /// Activates a feature (e.g. when a sidebar section header is tapped)
    /// without changing that feature's internal selection.
    func activateFeature(_ featureID: String) {
        activeFeatureID = featureID
    }
}

extension ShellViewModel: FeatureSelectionSyncing {
    func setSelection(_ selection: AnyHashable?, for featureID: String) {
        selectionBinding(for: featureID).wrappedValue = selection
    }
}
