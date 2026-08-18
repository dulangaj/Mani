import Foundation

/// Converts Markdown to what Slack's message composer accepts on paste, which
/// overlaps with Markdown just enough to be dangerous: `*x*` is bold in Slack
/// and italic everywhere else, so a wrong answer renders as a plausible one.
/// The composer applies no list formatting to pasted text and has no heading
/// syntax, so those become literal bullets and bold lines.
///
/// Links are deliberately left as `[text](url)`, which the composer converts on
/// send. The `<url|text>` form belongs to `chat.postMessage` and Block Kit, and
/// pastes as its own literal text.
nonisolated enum SlackMarkdown {
    static func from(_ markdown: String) -> String {
        // Local rather than static, because a `Regex` is not `Sendable`.

        /// Headings become bold, via `**`, which the inline pass then narrows.
        let heading = #/^[ \t]*#{1,6}[ \t]+(.+?)[ \t]*$/#

        /// Pasted text gets no list formatting, only the character you type.
        let bullet = #/^([ \t]*)[-*+][ \t]+/#

        /// Paragraph tags, which a small model reaches for when it decides the
        /// answer wants markup that Markdown does not cover.
        let html = #/<\s*/?\s*(?:p|br)\s*/?\s*>/#

        /// One left-to-right pass, so `**b**` is consumed before the `*i*`
        /// branch can reach its asterisks. Inline code is matched first and
        /// returned untouched, keeping `*` and `_` inside backticks intact.
        let inline = #/`[^`\n]*`|\*\*(.+?)\*\*|~~(.+?)~~|\*(.+?)\*/#

        return outsideFences(markdown) { line in
            let bulleted = line
                .replacing(html, with: "")
                .replacing(heading) { "**\($0.output.1)**" }
                .replacing(bullet) { "\($0.output.1)• " }
            return String(bulleted.replacing(inline) { match in
                let (whole, bold, strike, italic) = match.output
                if let bold { return "*\(bold)*" }
                if let strike { return "~\(strike)~" }
                if let italic { return "_\(italic)_" }
                return String(whole)
            })
        }
    }

    /// Runs `body` over every line outside a ``` fence, so code samples keep
    /// their own punctuation.
    private static func outsideFences(_ text: String, _ body: (Substring) -> String) -> String {
        var isFenced = false
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("```") else {
                isFenced.toggle()
                return String(line)
            }
            return isFenced ? String(line) : body(line)
        }
        return lines.joined(separator: "\n")
    }
}
