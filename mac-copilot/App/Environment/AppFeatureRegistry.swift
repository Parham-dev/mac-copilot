import Foundation
import Combine

/// Ordered list of registered top-level features.
///
/// Order determines sidebar order.
/// Built once in `AppEnvironment.init` and injected as an environment object so
/// `ShellSidebarView` and `ShellDetailView` can iterate it without knowing any
/// feature-specific types.
@MainActor
final class AppFeatureRegistry: ObservableObject {
    let features: [FeatureModule]

    init(features: [FeatureModule]) {
        self.features = features
    }
}
