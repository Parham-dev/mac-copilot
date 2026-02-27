import Foundation

/// Namespace for the Profile feature.
///
/// Profile is no longer registered as a sidebar feature module — it is opened
/// as a sheet from the Settings popover in the sidebar footer. The `featureID`
/// is kept for reference should the feature ever be re-registered.
enum ProfileFeatureModule {
    static let featureID = "profile"
}
