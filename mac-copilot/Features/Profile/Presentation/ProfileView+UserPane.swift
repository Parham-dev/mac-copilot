import SwiftUI

extension ProfileView {
    var leftPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if let profile = viewModel.userProfile {
                    userCard(profile)
                } else if viewModel.isLoading {
                    userCardPlaceholder
                } else {
                    userCardEmpty
                }

                Divider()

                copilotStatusSection
            }
            .padding(16)
        }
    }

    func userCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    if let name = profile.name, !name.isEmpty {
                        Text(name)
                            .font(.headline)
                    }
                    Text("@\(profile.login)")
                        .font(profile.name != nil ? .subheadline : .headline)
                        .foregroundStyle(profile.name != nil ? .secondary : .primary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if let email = profile.email, !email.isEmpty {
                    profileRow(icon: "envelope", label: email)
                }
                if let company = profile.company, !company.isEmpty {
                    profileRow(icon: "building.2", label: company)
                }
                if let plan = profile.plan {
                    profileRow(icon: "creditcard", label: plan.capitalized)
                }
            }

            HStack(spacing: 0) {
                if let repos = profile.publicRepos {
                    statCell(value: "\(repos)", label: "Repos")
                }
                if let followers = profile.followers {
                    Divider().frame(height: 30)
                    statCell(value: "\(followers)", label: "Followers")
                }
            }
            .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    var userCardPlaceholder: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quaternary)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 80, height: 12)
            }
        }
        .padding(.vertical, 4)
    }

    var userCardEmpty: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No profile loaded")
                .foregroundStyle(.secondary)
        }
    }

    func profileRow(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.callout)
        }
    }

    func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
