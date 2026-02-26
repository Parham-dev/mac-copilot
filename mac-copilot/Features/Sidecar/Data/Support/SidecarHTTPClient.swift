import Foundation

struct SidecarHTTPResponse {
    let data: Data
    let statusCode: Int
}

enum SidecarHTTPClientError: LocalizedError {
    case invalidResponse
    case sidecarNotReady
    case unknownFailure

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from local sidecar"
        case .sidecarNotReady:
            return "Local sidecar is still starting. Please retry in a moment."
        case .unknownFailure:
            return "Unknown sidecar request failure"
        }
    }
}

@MainActor
final class SidecarHTTPClient {
    private let baseURL: URL
    private let sidecarLifecycle: SidecarLifecycleManaging
    private let transport: HTTPDataTransporting
    private let delayScheduler: AsyncDelayScheduling
    private let loggerPrefix = "[CopilotForge][SidecarHTTP]"

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: SidecarLifecycleManaging,
        transport: HTTPDataTransporting? = nil,
        delayScheduler: AsyncDelayScheduling? = nil
    ) {
        self.baseURL = baseURL
        self.sidecarLifecycle = sidecarLifecycle
        self.transport = transport ?? URLSessionHTTPDataTransport()
        self.delayScheduler = delayScheduler ?? TaskAsyncDelayScheduler()
    }

    func get(path: String) async throws -> SidecarHTTPResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        return try await sendWithRetry(request: request)
    }

    func post<RequestBody: Encodable>(path: String, body: RequestBody) async throws -> SidecarHTTPResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await sendWithRetry(request: request)
    }

    func isRecoverableConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet, .cannotFindHost:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.networkConnectionLost.rawValue
    }

    func waitForSidecarReady(maxAttempts: Int, delaySeconds: TimeInterval) async -> Bool {
        await waitForSidecarReadyInternal(maxAttempts: maxAttempts, delaySeconds: delaySeconds)
    }

    private func sendWithRetry(request: URLRequest) async throws -> SidecarHTTPResponse {
        let requestPath = request.url?.path ?? "<unknown>"

        await ensureSidecarStartedIfUnavailable(requestPath: requestPath)
        let initialReady = await waitForSidecarReadyInternal(maxAttempts: 12, delaySeconds: 0.25)
        if !initialReady {
            NSLog("%@ preflight wait timed out path=%@", loggerPrefix, requestPath)
        }

        var lastError: Error?
        for attempt in 0 ... 2 {
            do {
                return try await perform(request: request)
            } catch {
                lastError = error
                let recoverable = isRecoverableConnectionError(error)

                if recoverable, attempt < 2 {
                    await ensureSidecarStartedIfUnavailable(force: true, requestPath: requestPath)
                    let ready = await waitForSidecarReadyInternal(maxAttempts: 16, delaySeconds: 0.30)
                    if !ready {
                        NSLog("%@ sidecar not ready after retry wait path=%@", loggerPrefix, requestPath)
                        throw SidecarHTTPClientError.sidecarNotReady
                    }
                    continue
                }

                NSLog(
                    "%@ request failure path=%@ attempt=%d recoverable=%@ error=%@",
                    loggerPrefix,
                    requestPath,
                    attempt + 1,
                    recoverable ? "true" : "false",
                    error.localizedDescription
                )

                throw error
            }
        }

        throw lastError ?? SidecarHTTPClientError.unknownFailure
    }

    private func ensureSidecarStartedIfUnavailable(force: Bool = false, requestPath: String = "<unknown>") async {
        if !force, await pingHealth() {
            return
        }

        if force {
            NSLog("%@ startIfNeeded requested path=%@ force=true", loggerPrefix, requestPath)
        }
        sidecarLifecycle.startIfNeeded()
    }

    private func perform(request: URLRequest) async throws -> SidecarHTTPResponse {
        var bounded = request
        bounded.timeoutInterval = 12

        let (data, response) = try await transport.data(for: bounded)
        guard let http = response as? HTTPURLResponse else {
            throw SidecarHTTPClientError.invalidResponse
        }

        return SidecarHTTPResponse(data: data, statusCode: http.statusCode)
    }

    private func waitForSidecarReadyInternal(maxAttempts: Int, delaySeconds: TimeInterval) async -> Bool {
        for attempt in 1 ... maxAttempts {
            if await pingHealth() {
                return true
            }

            if attempt < maxAttempts {
                try? await delayScheduler.sleep(seconds: max(delaySeconds, 0.1))
            }
        }

        return false
    }

    private func pingHealth() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.httpMethod = "GET"

        do {
            let (_, response) = try await transport.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200 ... 299).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
