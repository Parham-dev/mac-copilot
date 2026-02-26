import Foundation

enum StreamTextAssembler {
    static func merge(current: String, incoming: String) -> String {
        guard !incoming.isEmpty else { return current }
        guard !current.isEmpty else { return incoming }

        let currentComparable = canonicalForComparison(current)
        let incomingComparable = canonicalForComparison(incoming)

        if incomingComparable == currentComparable {
            return current
        }

        if incomingComparable.hasPrefix(currentComparable) {
            return normalizeReadable(incoming)
        }

        if currentComparable.hasPrefix(incomingComparable) {
            return current
        }

                if let overlapCount = longestSuffixPrefixOverlap(lhs: current, rhs: incoming),
                     shouldApplyOverlapDedup(lhs: current, rhs: incoming, overlapCount: overlapCount) {
                        let suffix = String(incoming.dropFirst(overlapCount))
            return normalizeReadable(current + suffix)
        }

        if incomingComparable.count > currentComparable.count, incomingComparable.contains(currentComparable) {
                        return normalizeReadable(incoming)
        }

        if currentComparable.contains(incomingComparable) {
            return current
        }

        return normalizeReadable(appendWithBoundarySpacing(base: current, addition: incoming))
    }

    private static func longestSuffixPrefixOverlap(lhs: String, rhs: String) -> Int? {
        let maxCandidate = min(lhs.count, rhs.count)
        guard maxCandidate > 0 else { return nil }

        for length in stride(from: maxCandidate, through: 1, by: -1) {
            let lhsSuffix = lhs.suffix(length)
            let rhsPrefix = rhs.prefix(length)
            if lhsSuffix == rhsPrefix {
                return length
            }
        }

        return nil
    }

    private static func appendWithBoundarySpacing(base: String, addition: String) -> String {
        guard !addition.isEmpty else { return base }
        guard let left = base.last, let right = addition.first else { return base + addition }

        if shouldInsertLineBreakBeforeListItem(base: base, addition: addition) {
            return base + "\n" + addition
        }

        if shouldInsertOrderedListSpace(base: base, left: left, right: right) {
            return base + " " + addition
        }

        if shouldInsertSpace(between: left, and: right) {
            return base + " " + addition
        }

        return base + addition
    }

    private static func shouldInsertLineBreakBeforeListItem(base: String, addition: String) -> Bool {
        guard let left = base.last, !left.isWhitespace else { return false }

        return addition.range(of: "^\\d+[\\.|\\)]\\s", options: .regularExpression) != nil
    }

    private static func shouldInsertOrderedListSpace(base: String, left: Character, right: Character) -> Bool {
        if left == ".", right.isWordLike {
            let previous = base.dropLast().last
            if previous?.isNumber == true {
                return true
            }
        }

        if left.isNumber, right.isWordLike {
            return true
        }

        return false
    }

    private static func shouldApplyOverlapDedup(lhs: String, rhs: String, overlapCount: Int) -> Bool {
        guard overlapCount > 0 else { return false }
        if overlapCount >= 2 { return true }

        guard let overlapChar = lhs.last else { return false }
        return overlapChar.isWordLike
    }

    private static func compactPunctuationSpacing(_ text: String) -> String {
        text.replacingOccurrences(of: ": ", with: ":")
    }

    private static func canonicalForComparison(_ text: String) -> String {
        compactPunctuationSpacing(text)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeReadable(_ text: String) -> String {
        text.replacingOccurrences(
            of: ":(?=[\\p{L}\\p{N}])",
            with: ": ",
            options: .regularExpression
        )
    }

    private static func shouldInsertSpace(between left: Character, and right: Character) -> Bool {
        if left.isWhitespace || right.isWhitespace {
            return false
        }

        if left == ":" && right.isWordLike {
            return true
        }

        return false
    }

}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
    }

    var isWordLike: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
    }

    var isNumber: Bool {
        unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
    }
}
