import Foundation

/// How the strip field reads what you typed. Two modes, the pair every editor
/// that does this well offers: a literal string, and a regular expression.
nonisolated enum MatchMode: String, CaseIterable, Identifiable, Sendable {
    case plain = "Text"
    case regex = "Regex"

    var id: String { rawValue }
}

/// A search over the document. Both modes run through `NSRegularExpression`, so
/// a literal search is an escaped pattern and the two paths cannot drift apart.
nonisolated struct StripPattern: Sendable, Equatable {
    var text = ""
    var mode = MatchMode.plain
    var isCaseSensitive = false
    var isWholeWord = false

    /// Every hit, in document order. Empty matches are dropped: a pattern like
    /// `x*` matches between every pair of characters, which would report
    /// hundreds of hits and strip none of them.
    func ranges(in string: String) throws -> [NSRange] {
        guard !text.isEmpty else { return [] }
        let expression = try NSRegularExpression(
            pattern: pattern,
            options: isCaseSensitive ? [] : [.caseInsensitive]
        )
        let whole = NSRange(string.startIndex..., in: string)
        return expression.matches(in: string, range: whole).map(\.range).filter { $0.length > 0 }
    }

    /// The whole-word wrapper is a non-capturing group, so alternation inside a
    /// regular expression keeps binding the way it reads.
    private var pattern: String {
        let body = mode == .plain ? NSRegularExpression.escapedPattern(for: text) : text
        return isWholeWord ? #"\b(?:\#(body))\b"# : body
    }
}
