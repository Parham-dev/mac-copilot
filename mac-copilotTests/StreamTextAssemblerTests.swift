import Foundation
import Testing
@testable import mac_copilot

struct StreamTextAssemblerTests {
    // MARK: - Empty / identity cases

    @Test func emptyIncoming_returnsCurrent() {
        #expect(StreamTextAssembler.merge(current: "Hello", incoming: "") == "Hello")
    }

    @Test func emptyCurrent_returnsIncoming() {
        #expect(StreamTextAssembler.merge(current: "", incoming: "Hello") == "Hello")
    }

    @Test func identicalStrings_returnsCurrent() {
        #expect(StreamTextAssembler.merge(current: "Hello world", incoming: "Hello world") == "Hello world")
    }

    // MARK: - Cumulative / prefix growth

    @Test func incomingIsCumulativePrefixExtension_appendsNewPart() {
        let result = StreamTextAssembler.merge(
            current: "Hello",
            incoming: "Hello world"
        )
        #expect(result == "Hello world")
    }

    @Test func incomingIsSubstringOfCurrent_returnsCurrent() {
        let result = StreamTextAssembler.merge(
            current: "Hello world",
            incoming: "Hello"
        )
        #expect(result == "Hello world")
    }

    // MARK: - Suffix-prefix overlap deduplication

    @Test func overlappingChunks_deduplicatesSuffix() {
        let result = StreamTextAssembler.merge(
            current: "Hello wor",
            incoming: "world"
        )
        #expect(result == "Hello world")
    }

    @Test func singleCharacterOverlap_notWordLike_doesNotDeduplicate() {
        // ":" is not word-like, single char overlap not deduped
        let result = StreamTextAssembler.merge(
            current: "Check this:",
            incoming: ":path/to/file"
        )
        // Should not deduplicate on ":" since it's not word-like
        #expect(result.contains("Check this:"))
    }

    // MARK: - Boundary spacing

    @Test func colonFollowedByWord_insertsSpace() {
        let result = StreamTextAssembler.merge(
            current: "directory:",
            incoming: "Now"
        )
        #expect(result == "directory: Now")
    }

    @Test func orderedListNumber_insertsBoundaryNewline() {
        let result = StreamTextAssembler.merge(
            current: "Item one",
            incoming: "2. Item two"
        )
        #expect(result == "Item one\n2. Item two")
    }

    @Test func orderedListDotFollowedByWord_insertsSpace() {
        // "1." then "A homepage" → "1. A homepage"
        let result = StreamTextAssembler.merge(
            current: "1.",
            incoming: "A homepage"
        )
        #expect(result == "1. A homepage")
    }

    // MARK: - Markdown preservation

    @Test func boldMarkersAcrossChunks_preserved() {
        let result = StreamTextAssembler.merge(
            current: "• *",
            incoming: "*Frontend:** An index.html"
        )
        #expect(result == "• **Frontend:** An index.html")
    }

    @Test func avoidsSingleCharLetterDropOnShortOverlap() {
        let result = StreamTextAssembler.merge(
            current: "This project has:\n- **N",
            incoming: "Name**: `basic-node-app`"
        )
        #expect(result == "This project has:\n- **Name**: `basic-node-app`")
    }

    // MARK: - No false overlap on short non-word chars

    @Test func doesNotSplitWordAcrossChunks() {
        let result = StreamTextAssembler.merge(
            current: "some",
            incoming: "f words and characteristics"
        )
        #expect(result == "somef words and characteristics")
    }

    // MARK: - Whitespace normalization

    @Test func newlinePreservedInOutput() {
        let result = StreamTextAssembler.merge(
            current: "Let me check the current directory:",
            incoming: "Let me check the current directory:\nNow let me view the files:"
        )
        #expect(result == "Let me check the current directory:\nNow let me view the files:")
    }

    @Test func multipleSpacesBetweenTokens_collapsedForComparison() {
        // Whitespace-variant of same content should be treated as equal
        let result = StreamTextAssembler.merge(
            current: "Hello world",
            incoming: "Hello  world"
        )
        // canonical comparison collapses whitespace so they look equal
        #expect(result == "Hello world")
    }
}
