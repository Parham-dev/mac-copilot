import SwiftUI

struct UserProfileSummaryView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("@\(profile.login)")
                .font(.headline)

            if let name = profile.name, !name.isEmpty {
                Text(name)
            }

            if let email = profile.email, !email.isEmpty {
                Text(email)
                    .foregroundStyle(.secondary)
            }

            if let company = profile.company, !company.isEmpty {
                Text(company)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                if let repos = profile.publicRepos {
                    Text("Repos: \(repos)")
                }
                if let followers = profile.followers {
                    Text("Followers: \(followers)")
                }
                if let plan = profile.plan {
                    Text("Plan: \(plan)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
