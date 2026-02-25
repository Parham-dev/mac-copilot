import Foundation

struct RestoreAuthSessionUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository) {
        self.repository = repository
    }

    func execute() async {
        await repository.restoreSessionIfNeeded()
    }
}

struct StartGitHubDeviceFlowUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository) {
        self.repository = repository
    }

    func execute() async {
        await repository.startDeviceFlow()
    }
}

struct PollGitHubAuthorizationUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository) {
        self.repository = repository
    }

    func execute() async {
        await repository.pollForAuthorization()
    }
}

struct SignOutUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository) {
        self.repository = repository
    }

    func execute() {
        repository.signOut()
    }
}
