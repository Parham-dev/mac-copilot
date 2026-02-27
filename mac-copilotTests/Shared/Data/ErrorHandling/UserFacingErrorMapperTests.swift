import Foundation
import Testing
@testable import mac_copilot

struct UserFacingErrorMapperTests {
    @Test(.tags(.unit)) func returnsDescriptionForPlainError() {
        let error = SimpleError(message: "Something went wrong")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Something went wrong")
    }

    @Test(.tags(.unit)) func returnsFallbackWhenDescriptionStartsWithOperationCouldntBeCompleted() {
        let error = SimpleError(message: "The operation couldn't be completed. (Domain error 42.)")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test(.tags(.unit)) func returnsFallbackWhenDescriptionContainsErrorDomain() {
        let error = SimpleError(message: "Error Domain=NSURLErrorDomain Code=-1009")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test(.tags(.unit)) func returnsFallbackForEmptyDescription() {
        let error = SimpleError(message: "")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test(.tags(.unit)) func returnsFallbackForWhitespaceOnlyDescription() {
        let error = SimpleError(message: "   ")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback message")
        #expect(result == "Fallback message")
    }

    @Test(.tags(.unit)) func returnsMessageWhenDescriptionIsUserFriendly() {
        let error = SimpleError(message: "Connection timed out. Please try again.")
        let result = UserFacingErrorMapper.message(error, fallback: "Fallback")
        #expect(result == "Connection timed out. Please try again.")
    }
}

private struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
