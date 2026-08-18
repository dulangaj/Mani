import Foundation

/// What a find bar is looking for, and where in the list of hits it is
/// sitting. It holds no text of its own: `refresh(in:)` is called whenever the
/// document or the pattern changes. Nothing here knows what happens to a hit —
/// the strip bar removes it, a replace bar would rewrite it — which is what
/// keeps this reusable.
@MainActor
@Observable
final class FindController {
    var pattern = FindPattern()
    private(set) var matches: [NSRange] = []
    private(set) var isPatternValid = true
    private(set) var current = 0

    var status: String {
        if pattern.text.isEmpty { return "" }
        if !isPatternValid { return "Bad pattern" }
        return matches.isEmpty ? "No matches" : "\(current + 1) of \(matches.count)"
    }

    /// The index is kept rather than reset, so acting on one hit leaves the bar
    /// pointing at the one that took its place.
    func refresh(in text: String) {
        do {
            matches = try pattern.ranges(in: text)
            isPatternValid = true
        } catch {
            matches = []
            isPatternValid = false
        }
        current = min(current, max(matches.count - 1, 0))
    }

    var currentMatch: NSRange? {
        matches.indices.contains(current) ? matches[current] : nil
    }

    func step(_ delta: Int) -> NSRange? {
        guard !matches.isEmpty else { return nil }
        // `%` keeps the sign of its left operand, so the delta is folded into
        // range before the wrap, or a jump wider than the list goes negative.
        current = (current + delta % matches.count + matches.count) % matches.count
        return matches[current]
    }
}
