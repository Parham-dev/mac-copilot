import Foundation
import Testing
@testable import mac_copilot

struct NormalizedIDListTests {
    @Test(.tags(.unit)) func deduplicatesExactDuplicates() {
        let result = NormalizedIDList.from(["gpt-5", "gpt-5", "claude"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test(.tags(.unit)) func trimsWhitespace() {
        let result = NormalizedIDList.from(["  gpt-5 ", "\tclaude\n"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test(.tags(.unit)) func filtersEmptyStrings() {
        let result = NormalizedIDList.from(["gpt-5", "", "   ", "claude"])
        #expect(result == ["claude", "gpt-5"])
    }

    @Test(.tags(.unit)) func sortsCaseInsensitively() {
        let result = NormalizedIDList.from(["Zebra", "apple", "Mango"])
        #expect(result == ["apple", "Mango", "Zebra"])
    }

    @Test(.tags(.unit)) func returnsEmptyForEmptyInput() {
        #expect(NormalizedIDList.from([]).isEmpty)
    }

    @Test(.tags(.unit)) func preservesCaseButDeduplicatesExactMatches() {
        let result = NormalizedIDList.from(["GPT-5", "gpt-5"])
        #expect(result.count == 2)
        #expect(Set(result) == Set(["GPT-5", "gpt-5"]))
    }
}
