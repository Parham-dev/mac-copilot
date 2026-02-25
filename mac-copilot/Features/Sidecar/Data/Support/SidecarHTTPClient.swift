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

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:7878")!,
        sidecarLifecycle: SidecarLifecycleManaging
    ) {
        self.baseURL = baseURL
        self.sidecarLifecycle = sidecarLifecycle
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
        sidecarLifecycle.startIfNeeded()
        _ = await waitForSidecarReadyInternal(maxAttempts: 3, delaySeconds: 0.25)

        var lastError: Error?
        for attempt in 0 ... 1 {
            do {
                return try await perform(request: request)
            } catch {
                lastError = error
                if isRecoverableConnectionError(error), attempt == 0 {
                    sidecarLifecycle.startIfNeeded()
                    let ready = await waitForSidecarReadyInternal(maxAttempts: 8, delaySeconds: 0.30)
                    if !ready {
                        throw SidecarHTTPClientError.sidecarNotReady
                    }
                    continue
                }

                throw error
            }
        }

        throw lastError ?? SidecarHTTPClientError.unknownFailure
    }

    private func perform(request: URLRequest) async throws -> SidecarHTTPResponse {
        var bounded = request
        bounded.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: bounded)
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
                let nanos = UInt64(max(delaySeconds, 0.1) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }

        return false
    }

    private func pingHealth() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200 ... 299).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
