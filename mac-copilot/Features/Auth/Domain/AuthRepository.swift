import Foundation
import Combine

@MainActor
protocol AuthRepository {
    var state: AuthSessionState { get }
    var statePublisher: AnyPublisher<AuthSessionState, Never> { get }

    func restoreSessionIfNeeded() async
    func startDeviceFlow() async
    func pollForAuthorization() async
    func signOut()
    func currentAccessToken() -> String?
}
