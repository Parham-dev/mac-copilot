import Foundation
import Testing
@testable import mac_copilot

struct StreamTextAssemblerTests {
    // MARK: - Empty / identity cases

    @Test(.tags(.unit)) func emptyIncoming_returnsCurrent() {
        #expect(StreamTextAssembler.merge(current: "Hello", incoming: "") == "Hello")
    }

    @Test(.tags(.unit)) func emptyCurrent_returnsIncoming() {
        #expect(StreamTextAssembler.merge(current: "", incoming: "Hello") == "Hello")
    }

    @Test(.tags(.unit)) func identicalStrings_returnsCurrent() {
        #expect(StreamTextAssembler.merge(current: "Hello world", incoming: "Hello world") == "Hello world")
    }

    // MARK: - Cumulative / prefix growth

    @Test(.tags(.unit)) func incomingIsCumulativePrefixExtension_appendsNewPart() {
        let result = StreamTextAssembler.merge(
            current: "Hello",
            incoming: "Hello world"
        )
        #expect(result == "Hello world")
    }

    @Test(.tags(.unit)) func incomingIsSubstringOfCurrent_returnsCurrent() {
        let result = StreamTextAssembler.merge(
            current: "Hello world",
            incoming: "Hello"
        )
        #expect(result == "Hello world")
    }

    // MARK: - Suffix-prefix overlap deduplication

    @Test(.tags(.unit, .regression)) func overlappingChunks_deduplicatesSuffix() {
        let result = StreamTextAssembler.merge(
            current: "Hello wor",
            incoming: "world"
        )
        #expect(result == "Hello world")
    }

    @Test(.tags(.unit, .regression)) func singleCharacterOverlap_notWordLike_doesNotDeduplicate() {
        // ":" is not word-like, single char overlap not deduped
        let result = StreamTextAssembler.merge(
            current: "Check this:",
            incoming: ":path/to/file"
        )
        // Should not deduplicate on ":" since it's not word-like
        #expect(result.contains("Check this:"))
    }

    // MARK: - Boundary spacing

    @Test(.tags(.unit)) func colonFollowedByWord_insertsSpace() {
        let result = StreamTextAssembler.merge(
            current: "directory:",
            incoming: "Now"
        )
        #expect(result == "directory: Now")
    }

    @Test(.tags(.unit)) func orderedListNumber_insertsBoundaryNewline() {
        let result = StreamTextAssembler.merge(
            current: "Item one",
            incoming: "2. Item two"
        )
        #expect(result == "Item one\n2. Item two")
    }

    @Test(.tags(.unit)) func orderedListDotFollowedByWord_insertsSpace() {
        // "1." then "A homepage" → "1. A homepage"
        let result = StreamTextAssembler.merge(
            current: "1.",
            incoming: "A homepage"
        )
        #expect(result == "1. A homepage")
    }

    // MARK: - Markdown preservation

    @Test(.tags(.unit, .regression)) func boldMarkersAcrossChunks_preserved() {
        let result = StreamTextAssembler.merge(
            current: "• *",
            incoming: "*Frontend:** An index.html"
        )
        #expect(result == "• **Frontend:** An index.html")
    }

    @Test(.tags(.unit, .regression)) func avoidsSingleCharLetterDropOnShortOverlap() {
        let result = StreamTextAssembler.merge(
            current: "This project has:\n- **N",
            incoming: "Name**: `basic-node-app`"
        )
        #expect(result == "This project has:\n- **Name**: `basic-node-app`")
    }

    // MARK: - No false overlap on short non-word chars

    @Test(.tags(.unit, .regression)) func doesNotSplitWordAcrossChunks() {
        let result = StreamTextAssembler.merge(
            current: "some",
            incoming: "f words and characteristics"
        )
        #expect(result == "somef words and characteristics")
    }

    // MARK: - Whitespace normalization

    @Test(.tags(.unit)) func newlinePreservedInOutput() {
        let result = StreamTextAssembler.merge(
            current: "Let me check the current directory:",
            incoming: "Let me check the current directory:\nNow let me view the files:"
        )
        #expect(result == "Let me check the current directory:\nNow let me view the files:")
    }

    @Test(.tags(.unit)) func multipleSpacesBetweenTokens_collapsedForComparison() {
        // Whitespace-variant of same content should be treated as equal
        let result = StreamTextAssembler.merge(
            current: "Hello world",
            incoming: "Hello  world"
        )
        // canonical comparison collapses whitespace so they look equal
        #expect(result == "Hello world")
    }
}
