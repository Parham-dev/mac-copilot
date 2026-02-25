import Foundation

struct EndpointCheck: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let statusCode: Int
    let available: Bool
    let preview: String
}

struct UserProfile {
    let login: String
    let name: String?
    let email: String?
    let company: String?
    let publicRepos: Int?
    let followers: Int?
    let plan: String?
}

struct CopilotReport {
    let sessionReady: Bool
    let usingGitHubToken: Bool
    let oauthScope: String?
    let lastAuthAt: String?
    let lastAuthError: String?
}

struct ProfileSnapshot {
    let userProfile: UserProfile?
    let copilotReport: CopilotReport?
    let rawUserJSON: String
    let checks: [EndpointCheck]
}
