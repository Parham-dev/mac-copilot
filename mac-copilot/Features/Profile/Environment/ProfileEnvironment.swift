import Foundation
import Combine

/// Self-contained environment for the Profile feature.
///
/// Thin wrapper that makes Profile's dependency surface explicit and lets
/// `ProfileFeatureModule` receive it via a typed argument.
@MainActor
final class ProfileEnvironment: ObservableObject {
    let profileViewModel: ProfileViewModel

    init(profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
    }
}
