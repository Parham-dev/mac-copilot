import SwiftUI

/// Shell detail pane host.
///
/// Looks up the active feature from `AppFeatureRegistry` and delegates
/// rendering to `FeatureModule.detailView`. Falls back to an empty state
/// if no feature is active.
///
/// The shell never imports feature-specific types — detail views are built
/// via `FeatureModule.detailView` closures that return `AnyView`.
struct ShellDetailView: View {
    @ObservedObject var shellViewModel: ShellViewModel
    @EnvironmentObject private var featureRegistry: AppFeatureRegistry

    var body: some View {
        if let activeFeatureID = shellViewModel.activeFeatureID,
           let feature = featureRegistry.features.first(where: { $0.id == activeFeatureID }) {
            let selection = shellViewModel.selection(for: activeFeatureID)
            let idKey = "\(activeFeatureID)|\(selection.map { "\($0)" } ?? "nil")"
            feature.detailView(selection)
                // Force full view replacement when the feature changes OR when the
                // selection within the feature changes. Without the selection key,
                // switching chats inside a feature would not re-evaluate the detail
                // view because `activeFeatureID` alone doesn't change.
                .id(idKey)
        } else if let firstFeature = featureRegistry.features.first {
            // Default to the first registered feature if nothing is active yet
            let selection = shellViewModel.selection(for: firstFeature.id)
            let idKey = "\(firstFeature.id)|\(selection.map { "\($0)" } ?? "nil")"
            firstFeature.detailView(selection)
                .id(idKey)
        } else {
            ContentUnavailableView("No features registered", systemImage: "square.dashed")
        }
    }
}
