import Foundation

/// Line-oriented reshaping. Every operation here splits the text into lines and
/// rejoins them, which has two consequences worth knowing: CR and CRLF breaks
/// come back as LF, and a trailing newline survives as a trailing newline
/// rather than turning into an empty last line.
nonisolated enum Lines {
    /// Splits on any line break. A trailing break is reported separately, not
    /// emitted as a final empty element, so `join(split(x)) == x` for LF text.
    static func split(_ text: String) -> (lines: [Substring], trailingNewline: Bool) {
        var parts = text.split(separator: #/\R/#, omittingEmptySubsequences: false)
        let trailingNewline = parts.count > 1 && parts[parts.count - 1].isEmpty
        if trailingNewline { parts.removeLast() }
        return (parts, trailingNewline)
    }

    static func join<S: Sequence>(_ lines: S, trailingNewline: Bool) -> String
    where S.Element: StringProtocol {
        lines.joined(separator: "\n") + (trailingNewline ? "\n" : "")
    }

    /// Deterministic and locale-independent, so results never shift between
    /// machines. Case-insensitive because `apple` before `Banana` is what people
    /// mean by alphabetical, and numeric so `file2` sorts before `file10` —
    /// which is why there is no separate "natural sort" action. Lines that are
    /// equal apart from case are tiebroken by Unicode scalar order, making the
    /// ordering total and the sort stable in the only way that is observable.
    static func precedes(_ lhs: Substring, _ rhs: Substring) -> Bool {
        switch String(lhs).compare(String(rhs), options: [.caseInsensitive, .numeric], range: nil, locale: nil) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return lhs.unicodeScalars.lexicographicallyPrecedes(rhs.unicodeScalars) { $0.value < $1.value }
        }
    }

    static func sorted(_ text: String, descending: Bool = false) -> String {
        let (lines, trailingNewline) = split(text)
        let ordered = lines.sorted { precedes($0, $1) }
        return join(descending ? Array(ordered.reversed()) : ordered, trailingNewline: trailingNewline)
    }

    static func reversed(_ text: String) -> String {
        let (lines, trailingNewline) = split(text)
        return join(Array(lines.reversed()), trailingNewline: trailingNewline)
    }

    /// Order-preserving: the first occurrence of each line stays put and later
    /// copies are dropped. Comparison is exact, so `a` and `a ` are different
    /// lines, and repeated blank lines collapse like any other repeat.
    static func deduplicated(_ text: String) -> String {
        let (lines, trailingNewline) = split(text)
        var seen = Set<Substring>()
        return join(lines.filter { seen.insert($0).inserted }, trailingNewline: trailingNewline)
    }

    /// 1-based, right-aligned to the width of the last number, `". "` separator.
    static func numbered(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let (lines, trailingNewline) = split(text)
        let width = String(lines.count).count
        let numbered = lines.enumerated().map { index, line -> String in
            let number = String(index + 1)
            return String(repeating: " ", count: width - number.count) + number + ". " + line
        }
        return join(numbered, trailingNewline: trailingNewline)
    }

    static func shuffled(_ text: String) -> String {
        var generator = SystemRandomNumberGenerator()
        return shuffled(text, using: &generator)
    }

    /// Seedable variant. It exists so the shuffle can be pinned by a test; the
    /// app always goes through the system generator.
    static func shuffled<G: RandomNumberGenerator>(_ text: String, using generator: inout G) -> String {
        let (lines, trailingNewline) = split(text)
        return join(lines.shuffled(using: &generator), trailingNewline: trailingNewline)
    }
}
