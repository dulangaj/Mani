// Contract tests for Base64, hex, digests, and HTML entities.
//
// Decisions pinned here:
//   * Everything here works on the UTF-8 bytes of the text, including any
//     trailing newline — which is why a digest matches `shasum file` rather
//     than `echo -n … | shasum`.
//   * Encoding is strict, decoding is permissive: decoders ignore whitespace,
//     accept the URL-safe alphabet, and tolerate missing padding.
//   * Bytes that are not valid UTF-8 throw, because a text buffer cannot hold
//     them.
//   * HTML unescaping is total: an entity it does not know is left alone.

import Testing
@testable import Mani

@Suite("Base64")
struct Base64Tests {

    @Test func encodesASCII() {
        #expect(Transform.base64Encode.apply(to: "hello") == "aGVsbG8=")
    }

    @Test func encodesTheUTF8Bytes() {
        #expect(Transform.base64Encode.apply(to: "h\u{00E9}llo") == "aMOpbGxv")
    }

    @Test func encodesATrailingNewlineAsPartOfTheInput() {
        #expect(Transform.base64Encode.apply(to: "hello\n") == "aGVsbG8K")
    }

    @Test func encodingNeverWrapsLines() {
        let output = Transform.base64Encode.apply(to: String(repeating: "a", count: 500))
        #expect(!output.contains("\n"))
    }

    @Test func decodesBackToTheOriginal() throws {
        #expect(try Conversion.base64Decode.apply(to: "aGVsbG8=") == "hello")
    }

    @Test func decodeIgnoresWhitespaceAndLineBreaks() throws {
        #expect(try Conversion.base64Decode.apply(to: "aGVs\nbG8=") == "hello")
        #expect(try Conversion.base64Decode.apply(to: "  aGVsbG8=  ") == "hello")
    }

    @Test func decodeAcceptsMissingPadding() throws {
        #expect(try Conversion.base64Decode.apply(to: "aGVsbG8") == "hello")
    }

    // JWT segments are base64url with the padding stripped.
    @Test func decodeAcceptsTheURLSafeAlphabet() throws {
        #expect(try Conversion.base64Decode.apply(to: "Pz8_Pg") == "???>")
    }

    @Test func decodeOfEmptyIsEmpty() throws {
        #expect(try Conversion.base64Decode.apply(to: "") == "")
    }

    @Test func decodeRejectsCharactersOutsideTheAlphabet() {
        #expect(throws: FormatError.self) { try Conversion.base64Decode.apply(to: "aGVsbG8*") }
    }

    // A body length of 4n+1 cannot be produced by any encoder.
    @Test func decodeRejectsTruncatedInput() {
        #expect(throws: FormatError.self) { try Conversion.base64Decode.apply(to: "aGVsb") }
        #expect(throws: FormatError.self) { try Conversion.base64Decode.apply(to: "a") }
    }

    // Padding is stripped before the length is checked, so an over-padded but
    // otherwise sound body still decodes.
    @Test func decodeToleratesExcessPadding() throws {
        #expect(try Conversion.base64Decode.apply(to: "aGVsbG8=====") == "hello")
    }

    @Test func decodeRejectsBytesThatAreNotText() {
        #expect(throws: FormatError.self) { try Conversion.base64Decode.apply(to: "//4=") }
    }

    @Test func everyFailureIsAFormatError() {
        let error = #expect(throws: FormatError.self) { try Conversion.base64Decode.apply(to: "!!!!") }
        #expect(error?.message.hasPrefix("Not valid Base64:") == true)
    }

    @Test(arguments: ["hello", "h\u{00E9}llo", "a\nb\n", "  spaced  ", "\u{1F642}", "line1\nline2"])
    func encodeThenDecodeRoundTrips(input: String) throws {
        #expect(try Conversion.base64Decode.apply(to: Transform.base64Encode.apply(to: input)) == input)
    }
}

@Suite("Hex Bytes")
struct HexTests {

    @Test func encodesLowercaseWithNoSeparators() {
        #expect(Transform.hexEncode.apply(to: "hi") == "6869")
    }

    @Test func encodesTheUTF8Bytes() {
        #expect(Transform.hexEncode.apply(to: "h\u{00E9}llo") == "68c3a96c6c6f")
    }

    @Test func decodesBackToTheOriginal() throws {
        #expect(try Conversion.hexDecode.apply(to: "6869") == "hi")
    }

    @Test func decodeAcceptsUppercase() throws {
        #expect(try Conversion.hexDecode.apply(to: "6869".uppercased()) == "hi")
    }

    @Test func decodeAcceptsSeparatingWhitespace() throws {
        #expect(try Conversion.hexDecode.apply(to: "68 69") == "hi")
    }

    @Test func decodeAcceptsALeadingOhEx() throws {
        #expect(try Conversion.hexDecode.apply(to: "0x6869") == "hi")
    }

    @Test func decodeOfEmptyIsEmpty() throws {
        #expect(try Conversion.hexDecode.apply(to: "") == "")
    }

    @Test func decodeRejectsAnOddNumberOfDigits() {
        #expect(throws: FormatError.self) { try Conversion.hexDecode.apply(to: "686") }
    }

    @Test func decodeRejectsNonHexCharacters() {
        #expect(throws: FormatError.self) { try Conversion.hexDecode.apply(to: "68zz") }
    }

    @Test func decodeRejectsBytesThatAreNotText() {
        #expect(throws: FormatError.self) { try Conversion.hexDecode.apply(to: "fffe") }
    }

    @Test(arguments: ["hi", "h\u{00E9}llo", "a\nb\n", "\u{1F642}"])
    func encodeThenDecodeRoundTrips(input: String) throws {
        #expect(try Conversion.hexDecode.apply(to: Transform.hexEncode.apply(to: input)) == input)
    }
}

@Suite("Digests")
struct DigestTests {

    // The trailing newline is hashed. That is the difference between matching
    // `shasum file` and matching `echo -n abc | shasum`, and it is why both
    // values are pinned side by side.
    @Test func sha256HashesTheBytesItIsGiven() {
        #expect(Digests.hex("abc", .sha256)
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(Digests.hex("abc\n", .sha256)
                == "edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb")
    }

    @Test func md5MatchesTheKnownVector() {
        #expect(Digests.hex("abc", .md5) == "900150983cd24fb0d6963f7d28e17f72")
    }

    @Test func sha1MatchesTheKnownVector() {
        #expect(Digests.hex("abc", .sha1) == "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    @Test func sha512MatchesTheKnownVector() {
        #expect(Digests.hex("abc", .sha512) == "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                + "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
    }

    @Test(arguments: Digests.Algorithm.allCases)
    func outputIsLowercaseHexOfTheExpectedWidth(algorithm: Digests.Algorithm) {
        let output = Digests.hex("abc", algorithm)
        #expect(output.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        let expectedBytes = [Digests.Algorithm.md5: 16, .sha1: 20, .sha256: 32, .sha512: 64]
        #expect(output.count == expectedBytes[algorithm]! * 2)
    }

    // Empty in, empty out — the invariant every other non-failing action holds.
    // The true digest of the empty string is never what an empty buffer wanted.
    @Test(arguments: Digests.Algorithm.allCases)
    func emptyInputHashesToEmpty(algorithm: Digests.Algorithm) {
        #expect(Digests.hex("", algorithm) == "")
    }
}

@Suite("HTML Entities")
struct HTMLEntityTests {

    @Test func escapesTheFiveMarkupCharacters() {
        #expect(Transform.escapeHTML.apply(to: "<a href=\"x\">it's & more</a>")
                == "&lt;a href=&quot;x&quot;&gt;it&#39;s &amp; more&lt;/a&gt;")
    }

    // Scanning character by character means an ampersand is escaped exactly
    // once, never turned into &amp;amp;.
    @Test func ampersandIsEscapedOnlyOnce() {
        #expect(Transform.escapeHTML.apply(to: "a & b") == "a &amp; b")
    }

    @Test func unicodeAndEmojiStayLiteral() {
        #expect(Transform.escapeHTML.apply(to: "caf\u{00E9} \u{1F642}") == "caf\u{00E9} \u{1F642}")
    }

    @Test func unescapesNamedEntities() {
        #expect(Transform.unescapeHTML.apply(to: "&lt;p&gt;a &amp; b&lt;/p&gt;") == "<p>a & b</p>")
        #expect(Transform.unescapeHTML.apply(to: "&mdash;&nbsp;&copy;") == "\u{2014}\u{00A0}\u{00A9}")
    }

    // The table is short on purpose. Anything outside it is an unknown entity
    // and survives untouched, which is the next test.
    @Test func entitiesOutsideTheTableAreNotDecoded() {
        #expect(Transform.unescapeHTML.apply(to: "caf&eacute;") == "caf&eacute;")
    }

    @Test func unescapesDecimalAndHexReferences() {
        #expect(Transform.unescapeHTML.apply(to: "&#8212; and &#x2014;") == "\u{2014} and \u{2014}")
    }

    // Total, like Unescape JSON String: what it does not know, it leaves.
    @Test func unknownEntitiesPassThroughUnchanged() {
        #expect(Transform.unescapeHTML.apply(to: "&frobnicate;") == "&frobnicate;")
    }

    @Test func bareAndUnterminatedAmpersandsAreLeftAlone() {
        #expect(Transform.unescapeHTML.apply(to: "a & b &amp c") == "a & b &amp c")
    }

    @Test func outOfRangeAndSurrogateReferencesAreLeftAlone() {
        #expect(Transform.unescapeHTML.apply(to: "&#xD800;") == "&#xD800;")
        #expect(Transform.unescapeHTML.apply(to: "&#99999999;") == "&#99999999;")
    }

    @Test func escapeThenUnescapeRoundTrips() {
        let input = "<a href=\"x\">it's & more</a>"
        #expect(Transform.unescapeHTML.apply(to: Transform.escapeHTML.apply(to: input)) == input)
    }

    // Unescaping peels one layer at a time, so it is deliberately not
    // idempotent — the same shape as decodeURL applied twice.
    @Test func unescapeDoubleApplicationIsNotIdempotent() {
        let once = Transform.unescapeHTML.apply(to: "&amp;lt;")
        #expect(once == "&lt;")
        #expect(Transform.unescapeHTML.apply(to: once) == "<")
    }
}
