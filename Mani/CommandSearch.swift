import Foundation

/// Ranked matching for the command palette.
///
/// The rule is the one every palette uses and everyone already has in their
/// fingers: your letters must appear in the label, in order, but not
/// necessarily together — so "fjs" finds "Format JSON (Sort Keys)". Anything
/// cleverer (typo correction, acronym scoring, learned frecency) makes results
/// move around for reasons the user cannot see, which is exactly what a palette
/// must not do.
///
/// Ties break toward the match that starts earlier and is more contiguous, so
/// an exact prefix always wins.
nonisolated enum CommandSearch {
    static func matches(_ commands: [TextOperation], query: String) -> [TextOperation] {
        let needle = query.filter { !$0.isWhitespace }.lowercased()
        guard !needle.isEmpty else { return commands }
        return commands
            .compactMap { command -> (command: TextOperation, score: Int)? in
                guard let score = score(command.label.lowercased(), needle) else { return nil }
                return (command, score)
            }
            .enumerated()
            .sorted { ($0.element.score, $1.offset) > ($1.element.score, $0.offset) }
            .map(\.element.command)
    }

    /// Higher is better, or `nil` when the letters are not all there in order.
    /// Scoring is deliberately tiny: a point for landing at the start of the
    /// label or a word, a point for continuing the previous run, and a penalty
    /// for how late the first letter matched.
    private static func score(_ label: String, _ needle: String) -> Int? {
        var score = 0
        var index = label.startIndex
        var previousMatch: String.Index?
        var firstMatchOffset: Int?

        for character in needle {
            guard let found = label[index...].firstIndex(of: character) else { return nil }
            let previous = found == label.startIndex ? nil : label[label.index(before: found)]
            let isWordStart = previous.map { $0.isWhitespace || $0.isPunctuation } ?? true
            if isWordStart { score += 8 }
            if let previousMatch, label.index(after: previousMatch) == found { score += 4 }
            if firstMatchOffset == nil {
                firstMatchOffset = label.distance(from: label.startIndex, to: found)
            }
            previousMatch = found
            index = label.index(after: found)
        }
        return score - (firstMatchOffset ?? 0)
    }
}
