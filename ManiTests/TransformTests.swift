// Contract tests for Mani's pure text transforms and formatters.
// These tests define the API — see the accompanying decisions summary
// for every place a behaviour was ambiguous and had to be pinned down.

import Testing
@testable import Mani

// MARK: - Cross-cutting contract

@Suite("Transform Contract")
struct TransformContractTests {

    @Test func allSixteenCasesArePresent() {
        #expect(Transform.allCases.count == 16)
    }

    @Test func idsAreUnique() {
        let ids = Transform.allCases.map(\.id)
        #expect(Set(ids.map { "\($0)" }).count == Transform.allCases.count)
    }

    // Every transform maps the empty string to the empty string.
    @Test(arguments: Transform.allCases)
    func emptyStringStaysEmpty(transform: Transform) {
        #expect(transform.apply(to: "") == "")
    }

    // Idempotency holds for these transforms on non-adversarial input.
    // unescapeJSONString, escapeJSONString, unescapeShell, encodeURL and
    // decodeURL are intentionally excluded — see their dedicated
    // non-idempotence tests below for why.
    @Test(arguments: [
        (Transform.removeNewlines, "a\nb\r\nc"),
        (Transform.joinLines, "a\n\nb  \n  c"),
        (Transform.removeEmptyLines, "a\n\nb\n\nc"),
        (Transform.trimLines, " a \n b \n c "),
        (Transform.normalizeLineEndings, "a\r\nb\rc"),
        (Transform.removeSpaces, "a b\tc d"),
        (Transform.collapseSpaces, "a   b\t\tc"),
        (Transform.stripInvisibles, "a\u{200B}b\u{FEFF}c"),
        (Transform.stripANSI, "\u{1B}[1mBold\u{1B}[0m"),
        (Transform.toUppercase, "Hello World"),
        (Transform.toLowercase, "Hello World"),
    ])
    func idempotentTransforms(transform: Transform, input: String) {
        let once = transform.apply(to: input)
        let twice = transform.apply(to: once)
        #expect(once == twice)
    }
}

// MARK: - Line transforms

@Suite("Line Transforms")
struct LineTransformTests {

    // removeNewlines: deletes line breaks, no replacement inserted.

    @Test func removeNewlinesJoinsWithNoSpace() {
        #expect(Transform.removeNewlines.apply(to: "Hello\nWorld") == "HelloWorld")
    }

    @Test func removeNewlinesHandlesTrailingNewline() {
        #expect(Transform.removeNewlines.apply(to: "a\n") == "a")
    }

    @Test func removeNewlinesTreatsCRAndCRLFAsBreaksToo() {
        // CR, CRLF and LF are all "line breaks" for this transform.
        #expect(Transform.removeNewlines.apply(to: "a\r\nb\rc\n") == "abc")
    }

    @Test func removeNewlinesPreservesGraphemeClusters() {
        #expect(Transform.removeNewlines.apply(to: "😀\n👍") == "😀👍")
    }

    // joinLines: line breaks -> single space, surrounding horizontal
    // whitespace collapsed into that one space.

    @Test func joinLinesInsertsSingleSpace() {
        #expect(Transform.joinLines.apply(to: "Hello\nWorld") == "Hello World")
    }

    @Test func joinLinesCollapsesSurroundingHorizontalWhitespace() {
        #expect(Transform.joinLines.apply(to: "a   \n\t\tb") == "a b")
    }

    @Test func joinLinesCollapsesMultipleBlankLinesToOneSpace() {
        #expect(Transform.joinLines.apply(to: "a\n\n\nb") == "a b")
    }

    // Least-surprising choice: a leading/trailing line break would
    // otherwise leave a stray leading/trailing space, so the final
    // result is trimmed.
    @Test func joinLinesTrimsLeadingAndTrailingResult() {
        #expect(Transform.joinLines.apply(to: "a\nb\n") == "a b")
        #expect(Transform.joinLines.apply(to: "\na\nb") == "a b")
    }

    @Test func joinLinesOfOnlyNewlinesIsEmpty() {
        #expect(Transform.joinLines.apply(to: "\n\n") == "")
    }

    @Test func joinLinesPreservesGraphemeClusters() {
        #expect(Transform.joinLines.apply(to: "😀\n👍") == "😀 👍")
    }

    // removeEmptyLines: "empty" means literally zero-length, matching
    // the literal reading of the transform's name. Whitespace-only
    // lines are left alone — that's trimLines' job.

    @Test func removeEmptyLinesDropsZeroLengthLines() {
        #expect(Transform.removeEmptyLines.apply(to: "a\n\nb\nc") == "a\nb\nc")
    }

    @Test func removeEmptyLinesKeepsWhitespaceOnlyLines() {
        #expect(Transform.removeEmptyLines.apply(to: "a\n   \nb") == "a\n   \nb")
    }

    @Test func removeEmptyLinesDropsTrailingBlankFromTrailingNewline() {
        #expect(Transform.removeEmptyLines.apply(to: "a\nb\n") == "a\nb")
    }

    // CR/CRLF are recognised as line breaks too, which normalizes the
    // output to LF as a side effect of splitting/rejoining lines.
    @Test func removeEmptyLinesNormalizesCRLFAsSideEffect() {
        #expect(Transform.removeEmptyLines.apply(to: "a\r\n\r\nb") == "a\nb")
    }

    // trimLines: strips leading/trailing whitespace from each line.

    @Test func trimLinesStripsEachLine() {
        #expect(Transform.trimLines.apply(to: " a \n b \n c ") == "a\nb\nc")
    }

    @Test func trimLinesReducesWhitespaceOnlyLineToEmpty() {
        #expect(Transform.trimLines.apply(to: "a\n   \nb") == "a\n\nb")
    }

    @Test func trimLinesPreservesTrailingNewline() {
        // Unlike removeEmptyLines, trimLines never drops a line.
        #expect(Transform.trimLines.apply(to: "a\n") == "a\n")
    }

    @Test func trimLinesPreservesInternalGraphemeClusters() {
        #expect(Transform.trimLines.apply(to: " 😀 \n 👍 ") == "😀\n👍")
    }

    // normalizeLineEndings: CRLF and lone CR both become LF.

    @Test func normalizeLineEndingsConvertsCRLF() {
        #expect(Transform.normalizeLineEndings.apply(to: "a\r\nb") == "a\nb")
    }

    @Test func normalizeLineEndingsConvertsLoneCR() {
        #expect(Transform.normalizeLineEndings.apply(to: "a\rb") == "a\nb")
    }

    @Test func normalizeLineEndingsHandlesMixedInput() {
        #expect(Transform.normalizeLineEndings.apply(to: "a\r\nb\rc\nd") == "a\nb\nc\nd")
    }

    // CRLF is checked before a lone CR, greedily and left-to-right, so
    // "CR CR LF" is a lone CR followed by a CRLF, not CRLF + LF.
    @Test func normalizeLineEndingsScansCRLFGreedilyLeftToRight() {
        #expect(Transform.normalizeLineEndings.apply(to: "a\r\r\nb") == "a\n\nb")
    }
}

// MARK: - Whitespace transforms

@Suite("Whitespace Transforms")
struct WhitespaceTransformTests {

    // removeSpaces: deletes U+0020 and U+0009 only — not newlines, not NBSP.

    @Test func removeSpacesDeletesSpacesAndTabs() {
        #expect(Transform.removeSpaces.apply(to: "a b\tc") == "abc")
    }

    @Test func removeSpacesLeavesNewlinesAlone() {
        #expect(Transform.removeSpaces.apply(to: "a b\nc d") == "ab\ncd")
    }

    @Test func removeSpacesLeavesNonBreakingSpaceAlone() {
        // NBSP is a different code point; converting it is stripInvisibles' job.
        #expect(Transform.removeSpaces.apply(to: "a\u{00A0}b") == "a\u{00A0}b")
    }

    // collapseSpaces: runs of spaces/tabs -> exactly one space.

    @Test func collapseSpacesCollapsesRuns() {
        #expect(Transform.collapseSpaces.apply(to: "a   b") == "a b")
        #expect(Transform.collapseSpaces.apply(to: "a\t\tb") == "a b")
        #expect(Transform.collapseSpaces.apply(to: "a  \t  b") == "a b")
    }

    @Test func collapseSpacesLeavesSingleSpaceUnchanged() {
        #expect(Transform.collapseSpaces.apply(to: "a b") == "a b")
    }

    @Test func collapseSpacesLeavesNewlinesAlone() {
        #expect(Transform.collapseSpaces.apply(to: "a   \nb") == "a \nb")
    }

    // stripInvisibles: ZWSP/ZWNJ/ZWJ/BOM deleted; NBSP -> regular space.

    @Test func stripInvisiblesDeletesZeroWidthSpace() {
        #expect(Transform.stripInvisibles.apply(to: "a\u{200B}b") == "ab")
    }

    @Test func stripInvisiblesDeletesBOM() {
        #expect(Transform.stripInvisibles.apply(to: "\u{FEFF}abc") == "abc")
    }

    @Test func stripInvisiblesConvertsNBSPToRegularSpace() {
        #expect(Transform.stripInvisibles.apply(to: "a\u{00A0}b") == "a b")
    }

    @Test func stripInvisiblesHandlesMixedRun() {
        let input = "Hello\u{200C}\u{200D}\u{FEFF} World\u{00A0}!"
        #expect(Transform.stripInvisibles.apply(to: input) == "Hello World !")
    }

    // Nasty edge case: ZWJ is stripped unconditionally, including inside
    // an emoji ZWJ sequence. That visually decomposes a joined emoji
    // (e.g. family) into its separate component emoji — accepted as the
    // expected behaviour of a generic invisible-character stripper,
    // since deciding "is this ZWJ part of a glyph" is out of scope here.
    @Test func stripInvisiblesDecomposesEmojiZWJSequences() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}" // man ZWJ woman ZWJ girl
        #expect(Transform.stripInvisibles.apply(to: family) == "\u{1F468}\u{1F469}\u{1F467}")
    }
}

// MARK: - Case transforms

@Suite("Case Transforms")
struct CaseTransformTests {

    @Test func toUppercaseBasic() {
        #expect(Transform.toUppercase.apply(to: "Hello World") == "HELLO WORLD")
    }

    @Test func toLowercaseBasic() {
        #expect(Transform.toLowercase.apply(to: "Hello World") == "hello world")
    }

    @Test func toUppercaseLeavesEmojiAlone() {
        #expect(Transform.toUppercase.apply(to: "Hello 😀 World") == "HELLO 😀 WORLD")
    }

    // Uses Swift's locale-independent default case mapping (no locale is
    // part of the API), so German ß uppercases to "SS" per Unicode's
    // default mapping.
    @Test func toUppercaseExpandsGermanSharpS() {
        #expect(Transform.toUppercase.apply(to: "straße") == "STRASSE")
    }

    // Locale-independent default mapping again: Turkish dotted capital I
    // (U+0130) lowercases to "i" + combining dot above (U+0069 U+0307),
    // NOT the Turkish-locale dotless "i". No locale is part of the API,
    // so Turkish-specific casing rules are deliberately not applied.
    @Test func toLowercaseUsesUnicodeDefaultNotTurkishLocale() {
        #expect(Transform.toLowercase.apply(to: "İstanbul") == "i\u{0307}stanbul")
    }
}

// MARK: - Escape transforms

@Suite("Escape Transforms")
struct EscapeTransformTests {

    // unescapeJSONString: decodes \n \t \r \" \\ \/ \b \f \uXXXX in place.
    // Malformed/unrecognised escapes (dangling backslash at end of
    // string, unknown \x, truncated \u) are left unchanged rather than
    // thrown, since this operates on arbitrary text, not just valid JSON.

    @Test func unescapeJSONStringBasicEscapes() {
        #expect(Transform.unescapeJSONString.apply(to: #"Hello\nWorld"#) == "Hello\nWorld")
        #expect(Transform.unescapeJSONString.apply(to: #"a\tb"#) == "a\tb")
        #expect(Transform.unescapeJSONString.apply(to: #"a\rb"#) == "a\rb")
        #expect(Transform.unescapeJSONString.apply(to: #"a\/b"#) == "a/b")
        #expect(Transform.unescapeJSONString.apply(to: #"a\\b"#) == "a\\b")
    }

    @Test func unescapeJSONStringUnicodeEscape() {
        #expect(Transform.unescapeJSONString.apply(to: #"A"#) == "A")
    }

    @Test func unescapeJSONStringSurrogatePairDecodesToEmoji() {
        #expect(Transform.unescapeJSONString.apply(to: #"😀"#) == "😀")
    }

    // Nasty edge case: "\\n" is an escaped backslash followed by a
    // literal "n", not a newline. Escapes are resolved left-to-right,
    // non-overlapping, so the already-consumed backslash never pairs
    // again with the following character.
    @Test func unescapeJSONStringDoubleBackslashThenLiteralN() {
        #expect(Transform.unescapeJSONString.apply(to: #"a\\nb"#) == #"a\nb"#)
    }

    @Test func unescapeJSONStringLeavesDanglingTrailingBackslash() {
        #expect(Transform.unescapeJSONString.apply(to: #"abc\"#) == #"abc\"#)
    }

    @Test func unescapeJSONStringLeavesUnrecognisedEscapeUnchanged() {
        #expect(Transform.unescapeJSONString.apply(to: #"a\xb"#) == #"a\xb"#)
    }

    @Test func unescapeJSONStringLeavesTruncatedUnicodeEscapeUnchanged() {
        #expect(Transform.unescapeJSONString.apply(to: #"\u12"#) == #"\u12"#)
    }

    // escapeJSONString: the inverse. Only structural characters are
    // escaped; non-ASCII text (accents, emoji) is left literal — matching
    // "ensure_ascii=false"-style encoders, which is the least surprising
    // choice for a text tool that already displays Unicode natively.
    // "/" is deliberately NOT escaped to "\/".

    @Test func escapeJSONStringBasicEscapes() {
        #expect(Transform.escapeJSONString.apply(to: "Hello\nWorld") == #"Hello\nWorld"#)
        #expect(Transform.escapeJSONString.apply(to: "a\tb") == #"a\tb"#)
        #expect(Transform.escapeJSONString.apply(to: "a/b") == "a/b")
        #expect(Transform.escapeJSONString.apply(to: "a\\b") == #"a\\b"#)
        #expect(Transform.escapeJSONString.apply(to: "say \"hi\"") == ##"say \"hi\""##)
    }

    @Test func escapeJSONStringNamedControlEscapes() {
        #expect(Transform.escapeJSONString.apply(to: "x\u{08}y") == #"x\by"#)
        #expect(Transform.escapeJSONString.apply(to: "x\u{0C}y") == #"x\fy"#)
    }

    // Other control characters fall back to lowercase-hex \u00XX.
    @Test func escapeJSONStringOtherControlCharUsesLowercaseUnicodeEscape() {
        #expect(Transform.escapeJSONString.apply(to: "x\u{01}y") == #"x\u0001y"#)
    }

    @Test func escapeJSONStringLeavesUnicodeLiteral() {
        #expect(Transform.escapeJSONString.apply(to: "😀 says café") == "😀 says café")
    }

    @Test(arguments: [
        "plain text",
        "line1\nline2\ttabbed",
        "quote \" and backslash \\",
        "slash / stays",
        "emoji 😀 and é",
    ])
    func jsonEscapeUnescapeRoundTrips(_ text: String) {
        let escaped = Transform.escapeJSONString.apply(to: text)
        let unescaped = Transform.unescapeJSONString.apply(to: escaped)
        #expect(unescaped == text)
    }

    // unescapeShell: strips a backslash that escapes the following
    // character (generic \X -> X), independent of what X is — it does
    // NOT decode \n to a newline the way unescapeJSONString does.

    @Test func unescapeShellRemovesEscapingBackslash() {
        #expect(Transform.unescapeShell.apply(to: #"a\ b"#) == "a b")
        #expect(Transform.unescapeShell.apply(to: #"a\$b"#) == "a$b")
        #expect(Transform.unescapeShell.apply(to: ##"a\"b"##) == #"a"b"#)
    }

    @Test func unescapeShellDoesNotDecodeJSONEscapes() {
        // \n here means "backslash escaping the letter n", so the
        // backslash is dropped and "n" stays a literal letter.
        #expect(Transform.unescapeShell.apply(to: #"a\nb"#) == "anb")
    }

    @Test func unescapeShellBackslashEscapingBackslash() {
        #expect(Transform.unescapeShell.apply(to: #"a\\b"#) == "a\\b")
    }

    // Nasty edge case: a trailing backslash with nothing to escape is
    // left as-is rather than dropped or crashing.
    @Test func unescapeShellLeavesDanglingTrailingBackslash() {
        #expect(Transform.unescapeShell.apply(to: #"abc\"#) == #"abc\"#)
    }

    @Test func unescapeShellIsIdempotentWhenNoBackslashesRemain() {
        let once = Transform.unescapeShell.apply(to: #"\$HOME"#)
        let twice = Transform.unescapeShell.apply(to: once)
        #expect(once == "$HOME")
        #expect(once == twice)
    }

    // Non-idempotence, by design: resolving "\\n" leaves a literal
    // backslash immediately before "n", which a second pass would
    // misread as an escaped n. Same left-to-right collision as JSON
    // unescape above — this documents it rather than asserting it away.
    @Test func unescapeShellDoubleApplicationIsNotIdempotent() {
        let once = Transform.unescapeShell.apply(to: #"a\\nb"#)
        let twice = Transform.unescapeShell.apply(to: once)
        #expect(once == #"a\nb"#)
        #expect(twice == "anb")
        #expect(once != twice)
    }

    // stripANSI: removes CSI (colour/cursor) and OSC escape sequences.

    @Test func stripANSIRemovesSGRColourCodes() {
        #expect(Transform.stripANSI.apply(to: "\u{1B}[0mHello\u{1B}[0m") == "Hello")
        #expect(Transform.stripANSI.apply(to: "\u{1B}[1;31mError\u{1B}[0m") == "Error")
    }

    @Test func stripANSIRemovesCursorMovementSequences() {
        #expect(Transform.stripANSI.apply(to: "a\u{1B}[2Jb") == "ab")
        #expect(Transform.stripANSI.apply(to: "a\u{1B}[10;20Hb") == "ab")
    }

    @Test func stripANSIRemovesBELTerminatedOSCSequence() {
        #expect(Transform.stripANSI.apply(to: "a\u{1B}]0;My Title\u{07}b") == "ab")
    }

    @Test func stripANSIRemovesSTTerminatedOSCSequence() {
        let input = "\u{1B}]8;;http://example.com\u{1B}\\Link\u{1B}]8;;\u{1B}\\"
        #expect(Transform.stripANSI.apply(to: input) == "Link")
    }

    @Test func stripANSILeavesPlainTextUnchanged() {
        #expect(Transform.stripANSI.apply(to: "plain text") == "plain text")
    }

    @Test func stripANSIRemovesConsecutiveSequences() {
        #expect(Transform.stripANSI.apply(to: "\u{1B}[1m\u{1B}[31mBold Red\u{1B}[0m") == "Bold Red")
    }

    // decodeURL / encodeURL: RFC 3986 percent-encoding.
    // Unreserved set (A-Z a-z 0-9 - _ . ~) is left unescaped; space
    // becomes %20 (not "+" — this is generic percent-encoding, not
    // x-www-form-urlencoded). Correspondingly decodeURL leaves a literal
    // "+" as "+", it does not turn it into a space.

    @Test func encodeURLEscapesReservedCharacters() {
        #expect(Transform.encodeURL.apply(to: "hello world") == "hello%20world")
        #expect(Transform.encodeURL.apply(to: "a=b&c") == "a%3Db%26c")
    }

    @Test func encodeURLLeavesUnreservedCharactersUnescaped() {
        #expect(Transform.encodeURL.apply(to: "abc-_.~123") == "abc-_.~123")
    }

    @Test func encodeURLEncodesUnicodeAsUTF8Bytes() {
        #expect(Transform.encodeURL.apply(to: "héllo") == "h%C3%A9llo")
        #expect(Transform.encodeURL.apply(to: "😀") == "%F0%9F%98%80")
    }

    @Test func decodeURLDecodesPercentEscapes() {
        #expect(Transform.decodeURL.apply(to: "hello%20world") == "hello world")
        #expect(Transform.decodeURL.apply(to: "h%C3%A9llo") == "héllo")
        #expect(Transform.decodeURL.apply(to: "%F0%9F%98%80") == "😀")
    }

    @Test func decodeURLLeavesPlusAsLiteral() {
        #expect(Transform.decodeURL.apply(to: "a+b") == "a+b")
    }

    // Malformed sequences pass through unchanged rather than throwing —
    // apply(to:) is non-throwing, so this must be a total function.
    @Test func decodeURLLeavesMalformedSequencesUnchanged() {
        #expect(Transform.decodeURL.apply(to: "100%") == "100%")
        #expect(Transform.decodeURL.apply(to: "a%zzb") == "a%zzb")
    }

    // Non-idempotence, by design: a decoded "%25" becomes a literal "%",
    // which a second decode pass would treat as the start of a new
    // escape. decodeURL is only safe to apply once per encoding layer.
    @Test func decodeURLDoubleApplicationIsNotIdempotent() {
        let once = Transform.decodeURL.apply(to: "%2520")
        let twice = Transform.decodeURL.apply(to: once)
        #expect(once == "%20")
        #expect(twice == " ")
        #expect(once != twice)
    }

    // Same collision in the encode direction: encoding a literal "%"
    // produces "%25", so encoding twice produces "%2525".
    @Test func encodeURLDoubleApplicationIsNotIdempotent() {
        let once = Transform.encodeURL.apply(to: "100%")
        let twice = Transform.encodeURL.apply(to: once)
        #expect(once == "100%25")
        #expect(twice == "100%2525")
        #expect(once != twice)
    }

    @Test(arguments: [
        "hello world",
        "héllo wörld",
        "😀 party!",
        "100% done & happy=true",
        "a/b?c=d#e",
    ])
    func urlEncodeDecodeRoundTrips(_ text: String) {
        let encoded = Transform.encodeURL.apply(to: text)
        let decoded = Transform.decodeURL.apply(to: encoded)
        #expect(decoded == text)
    }
}

// MARK: - Formatters

@Suite("Formatters")
struct FormatterTests {

    // Formatter.json: 2-space indent, "key": value (no space before the
    // colon — the more common convention than JSONSerialization's
    // default "key" : value), "/" not escaped. Key and array element
    // order preserved as written; sortKeys: true sorts object keys.
    // Parsing is strict RFC 8259 JSON — no trailing commas, no comments.

    @Test func jsonPrettyPrintPreservesKeyOrderByDefault() throws {
        let input = #"{"b":2,"a":1}"#
        let expected = """
{
  "b": 2,
  "a": 1
}
"""
        #expect(try Formatter.json(input) == expected)
    }

    @Test func jsonPrettyPrintSortsKeysAndIndentsNestedArray() throws {
        let input = #"{"b":2,"a":1,"c":[3,2,1]}"#
        let expected = """
{
  "a": 1,
  "b": 2,
  "c": [
    3,
    2,
    1
  ]
}
"""
        #expect(try Formatter.json(input, sortKeys: true) == expected)
    }

    @Test func jsonPrettyPrintNestedObjectsAndArrays() throws {
        let input = #"{"a":[{"x":1,"y":2},{"z":3}],"b":{"c":{"d":4}}}"#
        let expected = """
{
  "a": [
    {
      "x": 1,
      "y": 2
    },
    {
      "z": 3
    }
  ],
  "b": {
    "c": {
      "d": 4
    }
  }
}
"""
        #expect(try Formatter.json(input) == expected)
    }

    @Test func jsonPreservesUnicodeLiterally() throws {
        let input = #"{"greeting":"héllo wörld 😀"}"#
        let expected = """
{
  "greeting": "héllo wörld 😀"
}
"""
        #expect(try Formatter.json(input) == expected)
    }

    @Test func jsonDoesNotEscapeForwardSlash() throws {
        let input = #"{"url":"http://example.com/path"}"#
        let expected = """
{
  "url": "http://example.com/path"
}
"""
        #expect(try Formatter.json(input) == expected)
    }

    @Test func jsonFormatsEmptyContainersInline() throws {
        let input = #"{"a":[],"b":{}}"#
        let expected = """
{
  "a": [],
  "b": {}
}
"""
        #expect(try Formatter.json(input) == expected)
    }

    @Test func jsonFormatsPrimitiveTypes() throws {
        let input = #"{"n":null,"t":true,"f":false,"num":3.14,"i":-5}"#
        let expected = """
{
  "f": false,
  "i": -5,
  "n": null,
  "num": 3.14,
  "t": true
}
"""
        #expect(try Formatter.json(input, sortKeys: true) == expected)
    }

    // A bare top-level scalar is valid JSON text (RFC 8259) and is
    // returned as-is — there's nothing to indent.
    @Test func jsonFormatsTopLevelScalar() throws {
        #expect(try Formatter.json("42") == "42")
    }

    @Test(arguments: [
        "{invalid}",
        #"{"a":}"#,
        #"{"a":1,}"#,
        "[1,2,",
        "",
    ])
    func jsonInvalidThrows(_ input: String) throws {
        #expect(throws: (any Error).self) { try Formatter.json(input) }
    }

    // Formatter.minifiedJSON: removes insignificant whitespace only.
    // Unlike json(), it preserves the original key order — minifying is
    // a pure formatting op, not a canonicalizing one.

    @Test func jsonMinifyRemovesInsignificantWhitespacePreservingKeyOrder() throws {
        let input = """
{
  "b": 2,
  "a": 1
}
"""
        #expect(try Formatter.minifiedJSON(input) == #"{"b":2,"a":1}"#)
    }

    @Test func jsonMinifyPreservesWhitespaceInsideStrings() throws {
        #expect(try Formatter.minifiedJSON(#"{"a": "b   c"}"#) == #"{"a":"b   c"}"#)
    }

    @Test func jsonMinifyIsIdempotent() throws {
        let once = try Formatter.minifiedJSON(#"{"b":2,"a":1}"#)
        let twice = try Formatter.minifiedJSON(once)
        #expect(once == twice)
    }

    @Test func jsonMinifyThenPrettyRoundTripsToSortedForm() throws {
        let input = #"{"b":2,"a":1,"c":[1,2]}"#
        let minified = try Formatter.minifiedJSON(input)
        #expect(try Formatter.json(minified, sortKeys: true) == Formatter.json(input, sortKeys: true))
    }

    // Formatter.xml: 2-space indent, attribute order preserved as
    // written (unlike JSON keys, XML attribute order can be semantically
    // meaningful, e.g. xmlns declarations, so it isn't reordered by
    // default; sortAttributes: true opts in to alphabetical order).
    // Elements with no children/text self-close as "<tag/>". CDATA is
    // preserved verbatim. A leading XML declaration is kept if present,
    // but never injected if absent — pretty-printing is formatting only,
    // it doesn't add content the input didn't have. Parsing is strict
    // well-formed XML.

    @Test func xmlPrettyPrintsCompactDocument() throws {
        let input = "<root><a>1</a><b>2</b></root>"
        let expected = """
<root>
  <a>1</a>
  <b>2</b>
</root>
"""
        #expect(try Formatter.xml(input) == expected)
    }

    @Test func xmlPreservesAttributeOrderAndCDATA() throws {
        let input = #"<note id="1" type="test"><content><![CDATA[Hello <world> & "friends"]]></content></note>"#
        let expected = """
<note id="1" type="test">
  <content><![CDATA[Hello <world> & "friends"]]></content>
</note>
"""
        #expect(try Formatter.xml(input) == expected)
    }

    @Test func xmlSelfClosesEmptyElements() throws {
        let input = #"<root><empty/><img src="x.png"></img></root>"#
        let expected = """
<root>
  <empty/>
  <img src="x.png"/>
</root>
"""
        #expect(try Formatter.xml(input) == expected)
    }

    @Test func xmlPreservesDeclarationWhenPresent() throws {
        let input = #"<?xml version="1.0" encoding="UTF-8"?><root><a>1</a></root>"#
        let expected = """
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <a>1</a>
</root>
"""
        #expect(try Formatter.xml(input) == expected)
    }

    @Test func xmlDoesNotInjectDeclarationWhenAbsent() throws {
        let result = try Formatter.xml("<root><a>1</a></root>")
        #expect(!result.hasPrefix("<?xml"))
    }

    @Test func xmlSortAttributesSortsRecursively() throws {
        let input = #"<root z="1" a="2"><item b="two" a="one">text</item></root>"#
        let expected = """
<root a="2" z="1">
  <item a="one" b="two">text</item>
</root>
"""
        #expect(try Formatter.xml(input, sortAttributes: true) == expected)
    }

    // Formatter.minifiedXML: strips inter-element whitespace into one
    // line. Declaration handling matches xml(): kept if present, never
    // injected.

    @Test func xmlMinifyCollapsesToOneLine() throws {
        let input = """
<root>
  <a>1</a>
  <empty/>
</root>
"""
        #expect(try Formatter.minifiedXML(input) == "<root><a>1</a><empty/></root>")
    }

    @Test func xmlMinifyPreservesDeclarationWhenPresent() throws {
        let input = """
<?xml version="1.0"?>
<root>
  <a>1</a>
</root>
"""
        #expect(try Formatter.minifiedXML(input) == #"<?xml version="1.0"?><root><a>1</a></root>"#)
    }

    @Test(arguments: [
        "<root><a></root>",
        "<root>",
        "not xml at all",
        "",
    ])
    func xmlInvalidThrows(_ input: String) throws {
        #expect(throws: (any Error).self) { try Formatter.xml(input) }
        #expect(throws: (any Error).self) { try Formatter.minifiedXML(input) }
    }
}

@Suite("Organizer")
struct OrganizerTests {
    @Test func unfencedStripsWholeAnswerFence() {
        #expect(Organizer.unfenced("```markdown\n# Title\n\n- item\n```") == "# Title\n\n- item")
        #expect(Organizer.unfenced("```\ntext\n```") == "text")
    }

    @Test func unfencedLeavesInnerFencesAndPlainTextAlone() {
        let mixed = "# Title\n\n```swift\nlet x = 1\n```"
        #expect(Organizer.unfenced(mixed) == mixed)
        #expect(Organizer.unfenced("  plain\n") == "plain")
    }
}
