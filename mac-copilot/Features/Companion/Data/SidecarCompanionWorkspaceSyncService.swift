import Foundation

@MainActor
final class SidecarCompanionWorkspaceSyncService: CompanionWorkspaceSyncing {
    private let projectRepository: ProjectRepository
    private let chatRepository: ChatRepository
    private let transport: SidecarHTTPClient

    init(
        projectRepository: ProjectRepository,
        chatRepository: ChatRepository,
        sidecarLifecycle: SidecarLifecycleManaging,
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!
    ) {
        self.projectRepository = projectRepository
        self.chatRepository = chatRepository
        self.transport = SidecarHTTPClient(baseURL: baseURL, sidecarLifecycle: sidecarLifecycle)
    }

    func syncWorkspaceSnapshot() async {
        let snapshot = buildSnapshot()

        if snapshot.projects.isEmpty && snapshot.chats.isEmpty && snapshot.messages.isEmpty {
            return
        }

        do {
            let response = try await transport.post(path: "companion/sync/snapshot", body: snapshot)
            guard (200 ... 299).contains(response.statusCode) else {
                NSLog("[CopilotForge][CompanionSync] snapshot sync failed with HTTP %d", response.statusCode)
                SentryMonitoring.captureMessage(
                    "Companion snapshot sync returned non-success status",
                    category: "companion_sync",
                    extras: ["statusCode": String(response.statusCode)],
                    throttleKey: "http_\(response.statusCode)"
                )
                return
            }

            NSLog(
                "[CopilotForge][CompanionSync] synced snapshot (projects=%d chats=%d messages=%d)",
                snapshot.projects.count,
                snapshot.chats.count,
                snapshot.messages.count
            )
        } catch {
            NSLog("[CopilotForge][CompanionSync] snapshot sync failed: %@", error.localizedDescription)
            SentryMonitoring.captureError(
                error,
                category: "companion_sync",
                throttleKey: "request_error"
            )
        }
    }
}

private extension SidecarCompanionWorkspaceSyncService {
    func buildSnapshot() -> CompanionWorkspaceSnapshot {
        let projects: [ProjectRef]
        do {
            projects = try projectRepository.fetchProjects()
        } catch {
            NSLog("[CopilotForge][CompanionSync] project snapshot build failed: %@", error.localizedDescription)
            SentryMonitoring.captureError(
                error,
                category: "companion_sync",
                throttleKey: "project_fetch_failed"
            )
            return CompanionWorkspaceSnapshot(projects: [], chats: [], messages: [])
        }

        var chats: [CompanionWorkspaceSnapshot.Chat] = []
        var messages: [CompanionWorkspaceSnapshot.Message] = []

        for project in projects {
            let projectChats: [ChatThreadRef]
            do {
                projectChats = try chatRepository.fetchChats(projectID: project.id)
            } catch {
                NSLog("[CopilotForge][CompanionSync] chat snapshot build failed for project %@: %@", project.name, error.localizedDescription)
                SentryMonitoring.captureError(
                    error,
                    category: "companion_sync",
                    throttleKey: "chat_fetch_failed"
                )
                continue
            }

            chats.append(contentsOf: projectChats.map {
                CompanionWorkspaceSnapshot.Chat(
                    id: $0.id.uuidString,
                    projectId: project.id.uuidString,
                    title: $0.title,
                    lastUpdatedAt: Self.iso8601.string(from: $0.createdAt)
                )
            })

            for chat in projectChats {
                let chatMessages: [ChatMessage]
                do {
                    chatMessages = try chatRepository.loadMessages(chatID: chat.id)
                } catch {
                    NSLog("[CopilotForge][CompanionSync] message snapshot build failed for chat %@: %@", chat.id.uuidString, error.localizedDescription)
                    SentryMonitoring.captureError(
                        error,
                        category: "companion_sync",
                        throttleKey: "message_fetch_failed"
                    )
                    continue
                }

                messages.append(contentsOf: chatMessages.map {
                    CompanionWorkspaceSnapshot.Message(
                        id: $0.id.uuidString,
                        chatId: chat.id.uuidString,
                        role: $0.role.rawValue,
                        text: $0.text,
                        createdAt: Self.iso8601.string(from: $0.createdAt)
                    )
                })
            }
        }

        let snapshotProjects = projects.map {
            CompanionWorkspaceSnapshot.Project(
                id: $0.id.uuidString,
                name: $0.name,
                localPath: $0.localPath,
                lastUpdatedAt: Self.iso8601.string(from: Date())
            )
        }

        return CompanionWorkspaceSnapshot(
            projects: snapshotProjects,
            chats: chats,
            messages: messages
        )
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct CompanionWorkspaceSnapshot: Encodable {
    struct Project: Encodable {
        let id: String
        let name: String
        let localPath: String
        let lastUpdatedAt: String
    }

    struct Chat: Encodable {
        let id: String
        let projectId: String
        let title: String
        let lastUpdatedAt: String
    }

    struct Message: Encodable {
        let id: String
        let chatId: String
        let role: String
        let text: String
        let createdAt: String
    }

    let projects: [Project]
    let chats: [Chat]
    let messages: [Message]
}
