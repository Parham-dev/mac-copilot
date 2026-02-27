import SwiftUI

/// A self-contained description of a top-level shell feature.
///
/// The shell holds an ordered array of `FeatureModule` values and uses them to:
///   - render sidebar sections via `sidebarSection`
///   - render the detail pane via `detailView`
///   - produce a navigation title via `navigationTitle`
///
/// `FeatureModule` is a concrete value type with closure-based view builders so the
/// shell never imports feature-specific types. Each feature constructs its module in
/// its own `*FeatureModule.swift` file and erases view types to `AnyView` there —
/// never at the call site.
struct FeatureModule: Identifiable {

    /// Stable string identifier. Used as the key in `ShellViewModel.selectionByFeature`
    /// and for sidebar highlight tracking.
    let id: String

    /// Builds the sidebar section for this feature.
    ///
    /// - Parameter selection: Binding to the feature's currently selected item, typed
    ///   as `AnyHashable?`. The feature wraps its own concrete selection type inside
    ///   `AnyHashable` and decodes on the way out.
    let sidebarSection: (_ selection: Binding<AnyHashable?>) -> AnyView

    /// Builds the detail view for the given selection.
    ///
    /// - Parameter selection: The currently selected item within this feature, or `nil`
    ///   if nothing is selected. The feature decodes from `AnyHashable` back to its own
    ///   concrete type.
    let detailView: (_ selection: AnyHashable?) -> AnyView

    /// Returns the navigation title appropriate for the current selection.
    let navigationTitle: (_ selection: AnyHashable?) -> String
}
