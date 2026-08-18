// Contract tests for the status bar summary.
//
// Line counting is deliberately left exactly as it was before word counting
// was added: a trailing newline still opens a final, empty line. A word is a
// maximal run of non-whitespace, so "state-of-the-art" counts once.

import Foundation
import Testing
@testable import Mani

@Suite("Text Stats")
struct TextStatsTests {

    @Test func emptyTextIsAllZeroes() {
        #expect(TextStats.summary(for: "") == "0 characters · 0 words · 0 lines")
    }

    @Test func whitespaceOnlyTextHasNoWords() {
        #expect(TextStats.summary(for: "   ") == "3 characters · 0 words · 1 line")
    }

    @Test func punctuationDoesNotSplitWords() {
        #expect(TextStats.summary(for: "hello, world") == "12 characters · 2 words · 1 line")
    }

    @Test func hyphenatedWordsCountOnce() {
        #expect(TextStats.summary(for: "state-of-the-art") == "16 characters · 1 word · 1 line")
    }

    @Test func newlinesSeparateWordsAndLines() {
        #expect(TextStats.summary(for: "a\nb") == "3 characters · 2 words · 2 lines")
    }

    // Unchanged from before words were counted: the trailing newline opens a
    // final, empty line.
    @Test func aTrailingNewlineOpensAnEmptyLine() {
        #expect(TextStats.summary(for: "a\n") == "2 characters · 1 word · 2 lines")
    }

    @Test func singularFormsAreUsedForOne() {
        #expect(TextStats.summary(for: "a") == "1 character · 1 word · 1 line")
    }

    @Test func emojiCountAsOneCharacterAndOneWord() {
        #expect(TextStats.summary(for: "\u{1F642}") == "1 character · 1 word · 1 line")
    }

    // Digit grouping comes from .formatted(), so the expectation is written
    // through the same API rather than hard-coding a locale's separator.
    @Test func largeCountsAreGrouped() {
        let summary = TextStats.summary(for: String(repeating: "a", count: 1234))
        #expect(summary.hasPrefix("\(1234.formatted()) characters"))
    }
}
