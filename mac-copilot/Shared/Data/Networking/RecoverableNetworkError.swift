import Foundation

enum RecoverableNetworkError {
    private static let recoverableURLCodes: Set<Int> = [
        NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorTimedOut,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotParseResponse,
        NSURLErrorBadServerResponse,
    ]

    static func isConnectionRelated(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }

        return recoverableURLCodes.contains(nsError.code)
    }
}
