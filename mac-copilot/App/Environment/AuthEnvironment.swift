import Foundation
import Combine

@MainActor
final class AuthEnvironment: ObservableObject {
    let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
}
