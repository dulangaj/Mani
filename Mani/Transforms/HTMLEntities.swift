import Foundation

/// HTML entity escaping and unescaping, done by hand. `NSAttributedString`'s
/// HTML importer is the obvious alternative and the wrong one: it is main-actor
/// bound, WebKit-backed, and rewrites the text around the entities.
nonisolated enum HTMLEntities {
    /// Only the five characters that actually need escaping in markup. Unicode
    /// and emoji stay literal, matching how `Escape as JSON String` behaves.
    /// The apostrophe becomes `&#39;` because `&apos;` is not HTML 4.
    static func escaped(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(character)
            }
        }
        return out
    }

    /// Total, like `Unescape JSON String`: an entity this does not recognise is
    /// left exactly as it was rather than throwing. Note that unescaping is not
    /// idempotent — `&amp;lt;` becomes `&lt;` becomes `<`.
    static func unescaped(_ text: String) -> String {
        text.replacing(#/&([#][0-9]+|[#][xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/#) { match in
            replacement(for: String(match.output.1)) ?? String(match.output.0)
        }
    }

    private static func replacement(for body: String) -> String? {
        if let known = named[body] { return known }
        var digits = Substring(body)
        guard digits.first == "#" else { return nil }
        digits.removeFirst()
        let radix: Int
        if digits.first == "x" || digits.first == "X" {
            digits.removeFirst()
            radix = 16
        } else {
            radix = 10
        }
        guard let value = UInt32(digits, radix: radix), let scalar = Unicode.Scalar(value) else { return nil }
        return String(Character(scalar))
    }

    private static let named: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{00A0}",
        "copy": "\u{00A9}",
        "reg": "\u{00AE}",
        "mdash": "\u{2014}",
        "ndash": "\u{2013}",
        "hellip": "\u{2026}",
        "lsquo": "\u{2018}",
        "rsquo": "\u{2019}",
        "ldquo": "\u{201C}",
        "rdquo": "\u{201D}",
    ]
}
