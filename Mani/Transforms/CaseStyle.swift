import Foundation

/// Identifier and prose case conversion. Every function here works per line and
/// never merges lines: camel-casing a 200-line file into one identifier is
/// never what anyone wants, and per-line lets you select a column of names and
/// convert the lot.
nonisolated enum CaseStyle {
    /// The shared tokenizer. Non-alphanumeric characters separate words;
    /// `lower→UPPER` and `digit→UPPER` start a new word; a run of capitals
    /// splits before the last one when a lowercase letter follows, so
    /// `XMLHttpRequest` is `XML`, `Http`, `Request`. Digits attach to the word
    /// in front of them, so `utf8Value` is `utf8`, `Value`.
    static func words(in line: some StringProtocol) -> [String] {
        let characters = Array(line)
        var words: [String] = []
        var current = ""
        for (index, character) in characters.enumerated() {
            guard character.isLetter || character.isNumber else {
                if !current.isEmpty { words.append(current); current = "" }
                continue
            }
            if current.isEmpty {
                current.append(character)
                continue
            }
            let previous = characters[index - 1]
            var startsWord = false
            if character.isUppercase {
                if previous.isLowercase || previous.isNumber {
                    startsWord = true
                } else if previous.isUppercase, index + 1 < characters.count, characters[index + 1].isLowercase {
                    startsWord = true
                }
            }
            if startsWord {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    static func camel(_ text: String) -> String {
        mapWords(text) { words in
            guard let first = words.first else { return "" }
            return first.lowercased() + words.dropFirst().map(capitalized).joined()
        }
    }

    static func pascal(_ text: String) -> String {
        mapWords(text) { $0.map(capitalized).joined() }
    }

    static func snake(_ text: String) -> String {
        mapWords(text) { $0.map { $0.lowercased() }.joined(separator: "_") }
    }

    static func kebab(_ text: String) -> String {
        mapWords(text) { $0.map { $0.lowercased() }.joined(separator: "-") }
    }

    static func constant(_ text: String) -> String {
        mapWords(text) { $0.map { $0.uppercased() }.joined(separator: "_") }
    }

    /// A different algorithm from the identifier cases: this one rewrites in
    /// place, so punctuation and spacing survive. Apostrophes count as word
    /// characters, which is why `Foundation`'s own `.capitalized` is not used —
    /// it turns "don't" into "Don'T". There is deliberately no small-word rule;
    /// "of" and "the" get capitalized too, because deterministic beats clever.
    static func title(_ text: String) -> String {
        mapLines(text) { line in
            var out = ""
            var atWordStart = true
            for character in line {
                if character.isLetter || character.isNumber || character == "'" || character == "\u{2019}" {
                    out += atWordStart ? character.uppercased() : character.lowercased()
                    atWordStart = false
                } else {
                    out.append(character)
                    atWordStart = true
                }
            }
            return out
        }
    }

    /// Folds diacritics but keeps non-Latin scripts: `Crème` becomes `creme`,
    /// while `日本語` is left standing rather than deleted.
    static func slug(_ text: String) -> String {
        mapLines(text) { line in
            let folded = String(line).folding(options: [.diacriticInsensitive], locale: nil).lowercased()
            var out = ""
            var pendingSeparator = false
            for character in folded {
                if character.isLetter || character.isNumber {
                    if pendingSeparator && !out.isEmpty { out.append("-") }
                    pendingSeparator = false
                    out.append(character)
                } else {
                    pendingSeparator = true
                }
            }
            return out
        }
    }

    private static func capitalized(_ word: String) -> String {
        word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }

    private static func mapWords(_ text: String, _ body: ([String]) -> String) -> String {
        mapLines(text) { line in body(words(in: line)) }
    }

    private static func mapLines(_ text: String, _ body: (Substring) -> String) -> String {
        let (lines, trailingNewline) = Lines.split(text)
        return Lines.join(lines.map(body), trailingNewline: trailingNewline)
    }
}
