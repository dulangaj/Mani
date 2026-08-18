import Foundation

/// A one-shot, non-failing text transformation. Totality is the contract here:
/// every case maps any input to some output, which is what lets the whole menu
/// be driven without a `try`. Operations that can legitimately reject their
/// input live in `Conversion` instead.
nonisolated enum Transform: CaseIterable, Identifiable, Sendable {
    // Lines
    case sortLines
    case sortLinesDescending
    case reverseLines
    case shuffleLines
    case removeDuplicateLines
    case numberLines
    // Line endings and whitespace
    case normalizeLineEndings
    case removeNewlines
    case joinLines
    case removeEmptyLines
    case trimLines
    case collapseSpaces
    case removeSpaces
    // Escapes and encodings
    case unescapeJSONString
    case escapeJSONString
    case unescapeShell
    case stripANSI
    case decodeURL
    case encodeURL
    case unescapeHTML
    case escapeHTML
    case base64Encode
    case hexEncode
    // Junk
    case stripInvisibles
    // Case
    case toUppercase
    case toLowercase
    case toTitleCase
    case toCamelCase
    case toPascalCase
    case toSnakeCase
    case toKebabCase
    case toConstantCase
    case toSlug

    var id: Self { self }

    var label: String {
        switch self {
        case .sortLines: "Sort Lines A\u{2192}Z"
        case .sortLinesDescending: "Sort Lines Z\u{2192}A"
        case .reverseLines: "Reverse Line Order"
        case .shuffleLines: "Shuffle Lines"
        case .removeDuplicateLines: "Remove Duplicate Lines"
        case .numberLines: "Number Lines"
        case .normalizeLineEndings: "Normalize Line Endings"
        case .removeNewlines: "Remove Newlines"
        case .joinLines: "Join Lines with Space"
        case .removeEmptyLines: "Remove Empty Lines"
        case .trimLines: "Trim Line Whitespace"
        case .collapseSpaces: "Collapse Spaces"
        case .removeSpaces: "Remove Spaces"
        case .unescapeJSONString: "Unescape JSON String"
        case .escapeJSONString: "Escape as JSON String"
        case .unescapeShell: "Unescape Shell Backslashes"
        case .stripANSI: "Strip Terminal Escapes"
        case .decodeURL: "Decode URL Percent-Encoding"
        case .encodeURL: "Encode URL Percent-Encoding"
        case .unescapeHTML: "Unescape HTML Entities"
        case .escapeHTML: "Escape HTML Entities"
        case .base64Encode: "Base64 Encode"
        case .hexEncode: "Encode as Hex Bytes"
        case .stripInvisibles: "Remove Invisible Characters"
        case .toUppercase: "Uppercase"
        case .toLowercase: "Lowercase"
        case .toTitleCase: "Title Case"
        case .toCamelCase: "camelCase"
        case .toPascalCase: "PascalCase"
        case .toSnakeCase: "snake_case"
        case .toKebabCase: "kebab-case"
        case .toConstantCase: "CONSTANT_CASE"
        case .toSlug: "Slugify"
        }
    }

    var help: String {
        switch self {
        case .sortLines: "Sort lines alphabetically, ignoring case and ordering embedded numbers naturally"
        case .sortLinesDescending: "Sort lines in reverse alphabetical order"
        case .reverseLines: "Put the last line first and the first line last"
        case .shuffleLines: "Reorder the lines at random"
        case .removeDuplicateLines: "Keep the first copy of each line and delete the rest, preserving order"
        case .numberLines: "Prefix every line with its number, right-aligned"
        case .normalizeLineEndings: "Convert Windows (CRLF) and old Mac (CR) line endings to Unix (LF)"
        case .removeNewlines: "Delete line breaks without adding spaces"
        case .joinLines: "Join all lines, separating them with a single space"
        case .removeEmptyLines: "Delete empty lines"
        case .trimLines: "Remove leading and trailing whitespace from every line"
        case .collapseSpaces: "Reduce runs of spaces and tabs to a single space"
        case .removeSpaces: "Delete all spaces and tabs, keeping line breaks"
        case .unescapeJSONString: #"Turn \n, \t, \", \\ and \uXXXX escapes into real characters"#
        case .escapeJSONString: "Escape the text for use inside a JSON string literal"
        case .unescapeShell: "Remove backslashes, keeping the characters they escape"
        case .stripANSI: "Remove ANSI terminal color codes, cursor moves, and hyperlinks"
        case .decodeURL: "Turn %20, %2F, %C3%A9 and friends back into characters"
        case .encodeURL: "Percent-encode everything except unreserved URL characters"
        case .unescapeHTML: "Turn &amp;, &#8212; and other HTML entities into real characters"
        case .escapeHTML: "Escape &, <, >, \" and ' as HTML entities"
        case .base64Encode: "Encode the UTF-8 bytes as Base64, including any trailing newline"
        case .hexEncode: "Encode the UTF-8 bytes as lowercase hex pairs"
        case .stripInvisibles: "Strip zero-width characters, BOMs, and bidi marks; convert non-breaking spaces to spaces"
        case .toUppercase: "Convert all text to uppercase"
        case .toLowercase: "Convert all text to lowercase"
        case .toTitleCase: "Capitalize the first letter of every word, leaving punctuation alone"
        case .toCamelCase: "Rewrite each line as a camelCase identifier"
        case .toPascalCase: "Rewrite each line as a PascalCase identifier"
        case .toSnakeCase: "Rewrite each line as a snake_case identifier"
        case .toKebabCase: "Rewrite each line as a kebab-case identifier"
        case .toConstantCase: "Rewrite each line as a CONSTANT_CASE identifier"
        case .toSlug: "Rewrite each line as a URL slug, folding accents to plain letters"
        }
    }

    func apply(to text: String) -> String {
        switch self {
        case .sortLines:
            Lines.sorted(text)
        case .sortLinesDescending:
            Lines.sorted(text, descending: true)
        case .reverseLines:
            Lines.reversed(text)
        case .shuffleLines:
            Lines.shuffled(text)
        case .removeDuplicateLines:
            Lines.deduplicated(text)
        case .numberLines:
            Lines.numbered(text)
        case .normalizeLineEndings:
            text.replacing(#/\R/#, with: "\n")
        case .removeNewlines:
            text.replacing(#/\R/#, with: "")
        case .joinLines:
            text.replacing(#/(?:[ \t]*\R)+[ \t]*/#, with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeEmptyLines:
            text.split(separator: #/\R/#, omittingEmptySubsequences: false)
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .trimLines:
            text.split(separator: #/\R/#, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        case .collapseSpaces:
            text.replacing(#/[ \t]+/#, with: " ")
        case .removeSpaces:
            text.replacing(#/[ \t]+/#, with: "")
        case .unescapeJSONString:
            Self.jsonUnescaped(text)
        case .escapeJSONString:
            Self.jsonEscaped(text)
        case .unescapeShell:
            text.replacing(#/\\(.)/#.dotMatchesNewlines()) { String($0.output.1) }
        case .stripANSI:
            // Port of chalk/ansi-regex: OSC sequences, then CSI and related escapes.
            text.replacing(#/(?:\x1B\][^\x07\x1B\x9C]*(?:\x07|\x1B\x5C|\x9C))|[\x1B\x9B][\[\]()#;?]*(?:\d{1,4}(?:[;:]\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~]/#, with: "")
        case .decodeURL:
            text.removingPercentEncoding ?? text
        case .encodeURL:
            text.addingPercentEncoding(withAllowedCharacters: Self.urlUnreserved) ?? text
        case .unescapeHTML:
            HTMLEntities.unescaped(text)
        case .escapeHTML:
            HTMLEntities.escaped(text)
        case .base64Encode:
            Bytes.base64Encoded(text)
        case .hexEncode:
            Bytes.hexEncoded(text)
        case .stripInvisibles:
            Self.strippedInvisibles(text)
        case .toUppercase:
            text.uppercased()
        case .toLowercase:
            text.lowercased()
        case .toTitleCase:
            CaseStyle.title(text)
        case .toCamelCase:
            CaseStyle.camel(text)
        case .toPascalCase:
            CaseStyle.pascal(text)
        case .toSnakeCase:
            CaseStyle.snake(text)
        case .toKebabCase:
            CaseStyle.kebab(text)
        case .toConstantCase:
            CaseStyle.constant(text)
        case .toSlug:
            CaseStyle.slug(text)
        }
    }

        /// RFC 3986 unreserved characters — everything else gets percent-encoded.
    private static let urlUnreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// Decodes JSON string escapes by round-tripping through JSONDecoder, which
    /// handles \uXXXX surrogate pairs correctly. Fails closed: malformed escapes
    /// return the input unchanged.
    private static func jsonUnescaped(_ text: String) -> String {
        // Raw control characters are illegal inside a JSON string; escape the common ones.
        var quoted = text.replacing(#/\R/#, with: "\\n").replacing("\t", with: "\\t")
        // Escape bare quotes, leaving existing escape pairs untouched.
        quoted = quoted.replacing(#/\\.|"/#) { $0.output == "\"" ? "\\\"" : String($0.output) }
        guard let data = "\"\(quoted)\"".data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data) else { return text }
        return decoded
    }

    private static func jsonEscaped(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(text),
              let quoted = String(data: data, encoding: .utf8) else { return text }
        return String(quoted.dropFirst().dropLast())
    }

    /// Removes zero-width and formatting scalars; converts non-breaking spaces
    /// to regular spaces. Works at the scalar level so junk hidden inside
    /// grapheme clusters is caught too.
    private static func strippedInvisibles(_ text: String) -> String {
        let removed: [ClosedRange<UInt32>] = [
            0xAD...0xAD,        // soft hyphen
            0x34F...0x34F,      // combining grapheme joiner
            0x200B...0x200F,    // zero-width space/non-joiner/joiner, LRM, RLM
            0x202A...0x202E,    // bidi embedding controls
            0x2060...0x2064,    // word joiner, invisible operators
            0x2066...0x206F,    // bidi isolates, deprecated format chars
            0xFEFF...0xFEFF,    // BOM
            0xFFF9...0xFFFB,    // interlinear annotation
        ]
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar.value == 0xA0 {
                scalars.append(" ")
            } else if removed.contains(where: { $0.contains(scalar.value) }) {
                continue
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}
