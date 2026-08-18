import Foundation

/// The status-bar summary, pulled out of the view so word counting is testable.
nonisolated enum TextStats {
    /// A word is a maximal run of non-whitespace, so `state-of-the-art` counts
    /// once. Line counting is left exactly as it was before words were added:
    /// a trailing newline still opens a final, empty line.
    static func summary(for text: String, kind: ContentKind? = nil) -> String {
        let characters = text.count
        let words = text.split(whereSeparator: \.isWhitespace).count
        let lines = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        let counts = "\(characters.formatted()) \(characters == 1 ? "character" : "characters")"
            + " · \(words.formatted()) \(words == 1 ? "word" : "words")"
            + " · \(lines.formatted()) \(lines == 1 ? "line" : "lines")"
        guard let kind else { return counts }
        return counts + " · \(kind.label)"
    }
}
