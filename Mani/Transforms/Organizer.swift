import Foundation
import FoundationModels

/// Rewrites text as structured Markdown using the on-device Apple
/// Intelligence model. Nothing leaves the machine.
nonisolated enum Organizer {
    static func markdown(_ text: String) async throws -> String {
        try checkAvailability()
        let session = LanguageModelSession(instructions: """
            Rewrite the user's text as clean, well-organized Markdown. \
            Use headings, lists, tables, and code fences where they fit. \
            Preserve every fact and detail; never add, invent, or drop content. \
            Respond with only the Markdown.
            """)
        do {
            return unfenced(try await session.respond(to: text).content)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            throw FormatError(message: "Text is too long for the on-device model. Select a smaller portion.")
        }
    }

    private static func checkAvailability() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw FormatError(message: "This Mac does not support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw FormatError(message: "Enable Apple Intelligence in System Settings to use Organize.")
        case .unavailable:
            throw FormatError(message: "The on-device model is not ready. Try again in a moment.")
        }
    }

    /// The model sometimes wraps its whole answer in a ```markdown fence.
    static func unfenced(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.wholeMatch(of: #/```[^\n]*\n(.*?)\n?```/#.dotMatchesNewlines()) else {
            return trimmed
        }
        return String(match.output.1)
    }
}
