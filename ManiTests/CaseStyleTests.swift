// Contract tests for case conversion.
//
// Decisions pinned here:
//   * Every case conversion works per line and never merges lines.
//   * One shared tokenizer: non-alphanumerics separate; lower→UPPER and
//     digit→UPPER start a word; a capital run splits before its last letter
//     when a lowercase follows; digits attach to the word in front of them.
//   * Title Case is a different algorithm — in place, punctuation-preserving,
//     apostrophes are word characters.
//   * Slugify folds diacritics but keeps non-Latin scripts.

import Foundation
import Testing
@testable import Mani

@Suite("Word Tokenizer")
struct WordTokenizerTests {

    @Test(arguments: [
        ("fooBar", ["foo", "Bar"]),
        ("XMLHttpRequest", ["XML", "Http", "Request"]),
        ("utf8Value", ["utf8", "Value"]),
        ("HTTP2Server", ["HTTP2", "Server"]),
        ("hello_world-again.txt", ["hello", "world", "again", "txt"]),
        ("  padded  ", ["padded"]),
        ("ALLCAPS", ["ALLCAPS"]),
        ("", []),
        ("---", []),
    ])
    func tokenizerSplitsAsSpecified(input: String, expected: [String]) {
        #expect(CaseStyle.words(in: input) == expected)
    }

    // Emoji are neither letters nor numbers, so they separate words.
    @Test func emojiSeparatesWords() {
        #expect(CaseStyle.words(in: "hello 😀 world") == ["hello", "world"])
    }
}

@Suite("Identifier Cases")
struct IdentifierCaseTests {

    // The single most important decision: conversion is per line.
    @Test(arguments: [
        (Transform.toCamelCase, "fooBar\nbazQux"),
        (Transform.toPascalCase, "FooBar\nBazQux"),
        (Transform.toSnakeCase, "foo_bar\nbaz_qux"),
        (Transform.toKebabCase, "foo-bar\nbaz-qux"),
        (Transform.toConstantCase, "FOO_BAR\nBAZ_QUX"),
        (Transform.toSlug, "foo-bar\nbaz-qux"),
    ])
    func conversionIsPerLine(transform: Transform, expected: String) {
        #expect(transform.apply(to: "foo bar\nbaz qux") == expected)
    }

    @Test func emptyLinesInsideTheTextSurvive() {
        #expect(Transform.toSnakeCase.apply(to: "foo bar\n\nbaz") == "foo_bar\n\nbaz")
    }

    @Test func allCapsInputLowercasesTheLeadingWord() {
        #expect(Transform.toCamelCase.apply(to: "HTTP SERVER") == "httpServer")
    }

    @Test func acronymsSplitBeforeTheFollowingWord() {
        #expect(Transform.toSnakeCase.apply(to: "XMLHttpRequest") == "xml_http_request")
    }

    @Test func digitsStayAttachedToTheWordInFront() {
        #expect(Transform.toSnakeCase.apply(to: "utf8Value") == "utf8_value")
    }

    @Test func punctuationIsDroppedByIdentifierCases() {
        #expect(Transform.toCamelCase.apply(to: "hello, world!") == "helloWorld")
    }

    // Round-tripping between the underscore and camel forms is stable.
    @Test func snakeToCamelToSnakeIsStable() {
        let snake = "foo_bar_baz"
        #expect(Transform.toSnakeCase.apply(to: Transform.toCamelCase.apply(to: snake)) == snake)
    }

    // Camel and Pascal are idempotent, but only because the tokenizer reads
    // their own output back as the same words. Pinned rather than assumed.
    @Test(arguments: ["fooBar", "HTTPServer", "utf8Value", "one"])
    func camelIsIdempotent(input: String) {
        let once = Transform.toCamelCase.apply(to: input)
        #expect(Transform.toCamelCase.apply(to: once) == once)
    }

    @Test func pascalUppercasesTheLeadingWord() {
        #expect(Transform.toPascalCase.apply(to: "http server") == "HttpServer")
    }
}

@Suite("Title Case")
struct TitleCaseTests {

    @Test func capitalizesEveryWordAndKeepsPunctuation() {
        #expect(Transform.toTitleCase.apply(to: "the quick brown fox.") == "The Quick Brown Fox.")
    }

    @Test func apostrophesAreWordCharacters() {
        #expect(Transform.toTitleCase.apply(to: "don't stop") == "Don't Stop")
    }

    @Test func curlyApostrophesCountToo() {
        #expect(Transform.toTitleCase.apply(to: "don\u{2019}t stop") == "Don\u{2019}t Stop")
    }

    // Documented lossiness: intercaps do not survive.
    @Test func intercapsAreFlattened() {
        #expect(Transform.toTitleCase.apply(to: "iOS and macOS") == "Ios And Macos")
    }

    // No small-word rule; deterministic beats clever.
    @Test func shortWordsAreCapitalizedToo() {
        #expect(Transform.toTitleCase.apply(to: "a tale of two cities") == "A Tale Of Two Cities")
    }

    @Test func leadingDigitsDoNotConsumeTheCapital() {
        #expect(Transform.toTitleCase.apply(to: "3rd place") == "3rd Place")
    }

    @Test func worksPerLine() {
        #expect(Transform.toTitleCase.apply(to: "one two\nthree four") == "One Two\nThree Four")
    }
}

@Suite("Slugify")
struct SlugifyTests {

    @Test func lowercasesAndHyphenatesDroppingPunctuation() {
        #expect(Transform.toSlug.apply(to: "Hello, World! 100% Sure") == "hello-world-100-sure")
    }

    @Test func foldsDiacritics() {
        #expect(Transform.toSlug.apply(to: "Cr\u{00E8}me Br\u{00FB}l\u{00E9}e") == "creme-brulee")
    }

    @Test func doesNotProduceLeadingOrTrailingHyphens() {
        #expect(Transform.toSlug.apply(to: "  !Hello World!  ") == "hello-world")
    }

    @Test func runsOfSeparatorsCollapseToOneHyphen() {
        #expect(Transform.toSlug.apply(to: "a --- b") == "a-b")
    }

    // Stripping non-Latin scripts would silently empty the line.
    @Test func keepsNonLatinScripts() {
        #expect(Transform.toSlug.apply(to: "\u{65E5}\u{672C}\u{8A9E} \u{30C6}\u{30AD}\u{30B9}\u{30C8}")
                == "\u{65E5}\u{672C}\u{8A9E}-\u{30C6}\u{30AD}\u{30B9}\u{30C8}")
    }

    @Test func aLineOfOnlyPunctuationBecomesEmpty() {
        #expect(Transform.toSlug.apply(to: "!!!") == "")
    }
}
