import Foundation

nonisolated struct FormatError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Pretty-printers that can fail. Failures throw; the caller must leave the
/// buffer untouched and surface the message.
nonisolated enum Formatter {
    /// Pretty-prints JSON: 2-space indent, keys sorted, empty containers
    /// inline. Scalar tokens are re-emitted verbatim, so number precision and
    /// string escapes survive byte-exact. Bare top-level scalars are valid.
    static func json(_ text: String) throws -> String {
        var out = ""
        emit(try JSONParser.parse(text), indent: 0, into: &out)
        return out
    }

    /// Removes all whitespace outside string literals, preserving key order.
    static func minifiedJSON(_ text: String) throws -> String {
        var out = ""
        emitCompact(try JSONParser.parse(text), into: &out)
        return out
    }

    /// Pretty-prints XML: 2-space indent, attribute order preserved, empty
    /// elements self-closed, CDATA kept verbatim. An existing XML declaration
    /// is kept as written; none is added if the input had none.
    static func xml(_ text: String) throws -> String {
        let document: XMLDocument
        do {
            document = try XMLDocument(xmlString: text, options: [.nodePreserveCDATA, .nodeLoadExternalEntitiesNever])
        } catch {
            let ns = error as NSError
            let detail = (ns.userInfo["NSDebugDescription"] as? String) ?? ns.localizedDescription
            throw FormatError(message: "Not valid XML: \(detail)")
        }
        let pretty = String(
            decoding: document.xmlData(options: [.nodePrettyPrint, .nodeCompactEmptyElement]),
            as: UTF8.self
        )
        // XMLDocument indents with 4 spaces; halve to 2.
        var output = pretty.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let content = line.drop(while: { $0 == " " })
                return String(repeating: " ", count: (line.count - content.count) / 2) + content
            }
            .joined(separator: "\n")
        // XMLDocument always emits a declaration; honor what the input had instead.
        let originalDeclaration = text.firstMatch(of: #/^\s*(<\?xml.*?\?>)/#.dotMatchesNewlines())?.output.1
        if let emitted = output.firstMatch(of: #/^<\?xml.*?\?>\n?/#.dotMatchesNewlines())?.range {
            if let originalDeclaration {
                output.replaceSubrange(emitted, with: originalDeclaration + "\n")
            } else {
                output.removeSubrange(emitted)
            }
        }
        return output
    }

    // MARK: - JSON emission

    private static func emit(_ value: JSONParser.Value, indent: Int, into out: inout String) {
        switch value {
        case .scalar(let raw):
            out += raw
        case .array(let items):
            guard !items.isEmpty else { out += "[]"; return }
            let pad = String(repeating: "  ", count: indent)
            out += "[\n"
            for (i, item) in items.enumerated() {
                out += pad + "  "
                emit(item, indent: indent + 1, into: &out)
                out += i == items.count - 1 ? "\n" : ",\n"
            }
            out += pad + "]"
        case .object(let entries):
            guard !entries.isEmpty else { out += "{}"; return }
            let pad = String(repeating: "  ", count: indent)
            out += "{\n"
            let sorted = entries.sorted { $0.key < $1.key }
            for (i, entry) in sorted.enumerated() {
                out += pad + "  " + entry.key + ": "
                emit(entry.value, indent: indent + 1, into: &out)
                out += i == sorted.count - 1 ? "\n" : ",\n"
            }
            out += pad + "}"
        }
    }

    private static func emitCompact(_ value: JSONParser.Value, into out: inout String) {
        switch value {
        case .scalar(let raw):
            out += raw
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += "," }
                emitCompact(item, into: &out)
            }
            out += "]"
        case .object(let entries):
            out += "{"
            for (i, entry) in entries.enumerated() {
                if i > 0 { out += "," }
                out += entry.key + ":"
                emitCompact(entry.value, into: &out)
            }
            out += "}"
        }
    }
}

/// Minimal strict RFC 8259 parser that keeps raw scalar tokens and key order.
/// Strict where JSONSerialization is lenient (e.g. trailing commas), and
/// re-emitting raw tokens sidesteps NSNumber double round-tripping entirely.
private nonisolated struct JSONParser {
    indirect enum Value {
        case object([(key: Substring, value: Value)])
        case array([Value])
        case scalar(Substring)
    }

    private let text: String
    private var index: String.Index

    static func parse(_ text: String) throws -> Value {
        var parser = JSONParser(text)
        parser.skipWhitespace()
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.index == text.endIndex else {
            throw parser.error("unexpected trailing characters")
        }
        return value
    }

    private init(_ text: String) {
        self.text = text
        index = text.startIndex
    }

    private mutating func parseValue() throws -> Value {
        switch peek() {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .scalar(try parseString())
        default: return .scalar(try parseLiteral())
        }
    }

    private mutating func parseObject() throws -> Value {
        advance() // {
        var entries: [(key: Substring, value: Value)] = []
        skipWhitespace()
        if peek() == "}" { advance(); return .object(entries) }
        while true {
            skipWhitespace()
            guard peek() == "\"" else { throw error("expected an object key") }
            let key = try parseString()
            skipWhitespace()
            guard peek() == ":" else { throw error("expected ':' after object key") }
            advance()
            skipWhitespace()
            entries.append((key, try parseValue()))
            skipWhitespace()
            switch peek() {
            case ",": advance()
            case "}": advance(); return .object(entries)
            default: throw error("expected ',' or '}' in object")
            }
        }
    }

    private mutating func parseArray() throws -> Value {
        advance() // [
        var items: [Value] = []
        skipWhitespace()
        if peek() == "]" { advance(); return .array(items) }
        while true {
            skipWhitespace()
            items.append(try parseValue())
            skipWhitespace()
            switch peek() {
            case ",": advance()
            case "]": advance(); return .array(items)
            default: throw error("expected ',' or ']' in array")
            }
        }
    }

    /// Returns the raw token including its quotes, validating escapes.
    private mutating func parseString() throws -> Substring {
        let start = index
        advance() // opening quote
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                advance()
                return text[start..<index]
            }
            if character == "\\" {
                advance()
                guard index < text.endIndex else { break }
                let escape = text[index]
                if escape == "u" {
                    for _ in 0..<4 {
                        advance()
                        guard index < text.endIndex, text[index].isHexDigit else {
                            throw error("invalid \\u escape")
                        }
                    }
                } else if !"\"\\/bfnrt".contains(escape) {
                    throw error("invalid escape '\\\(escape)'")
                }
                advance()
            } else if character.unicodeScalars.first!.value < 0x20 {
                throw error("raw control character in string")
            } else {
                advance()
            }
        }
        throw error("unterminated string")
    }

    private mutating func parseLiteral() throws -> Substring {
        let start = index
        while index < text.endIndex, !isDelimiter(text[index]) { advance() }
        let token = text[start..<index]
        guard token == "true" || token == "false" || token == "null"
                || token.wholeMatch(of: #/-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/#) != nil,
              !token.isEmpty else {
            throw error(token.isEmpty ? "unexpected end of input" : "unexpected token '\(token)'")
        }
        return token
    }

    // MARK: - Scanning

    private func peek() -> Character? {
        index < text.endIndex ? text[index] : nil
    }

    private mutating func advance() {
        index = text.index(after: index)
    }

    /// Scalar-level checks so a CRLF grapheme cluster is still seen as whitespace.
    private mutating func skipWhitespace() {
        while index < text.endIndex,
              text[index].unicodeScalars.allSatisfy({ "\u{20}\u{09}\u{0A}\u{0D}".unicodeScalars.contains($0) }) {
            advance()
        }
    }

    private func isDelimiter(_ character: Character) -> Bool {
        ",}] \t\r\n".unicodeScalars.contains(character.unicodeScalars.first!)
    }

    private func error(_ detail: String) -> FormatError {
        FormatError(message: "Not valid JSON: \(detail).")
    }
}
