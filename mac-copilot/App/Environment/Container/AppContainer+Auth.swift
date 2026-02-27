import Foundation
import FactoryKit

extension Container {
    var authService: Factory<GitHubAuthService> {
        self { @MainActor in
            GitHubAuthService(sidecarClient: self.sidecarAuthClient())
        }
            .singleton
    }

    var sidecarAuthClient: Factory<SidecarAuthClient> {
        self { @MainActor in
            SidecarAuthClient(sidecarLifecycle: self.sidecarLifecycleManager())
        }
        .singleton
    }

    var authRepository: Factory<any AuthRepository> {
        self { @MainActor in GitHubAuthRepository(service: self.authService()) }
            .singleton
    }

    var authViewModel: Factory<AuthViewModel> {
        self { @MainActor in AuthViewModel(repository: self.authRepository()) }
            .singleton
    }

    var profileRepository: Factory<any ProfileRepository> {
        self { @MainActor in
            GitHubProfileRepository(sidecarAuthClient: self.sidecarAuthClient())
        }
            .singleton
    }

    var profileViewModel: Factory<ProfileViewModel> {
        self { @MainActor in
            ProfileViewModel(fetchProfileUseCase: FetchProfileUseCase(repository: self.profileRepository()))
        }
        .singleton
    }
}