import Foundation
import FoundationModels

/// The house style an `Organize` run writes for. Jira Cloud reads standard
/// Markdown minus tables; Slack reads `mrkdwn`, which only looks like Markdown
/// and so is reached by rewriting the answer rather than by asking for it.
nonisolated enum OrganizeTarget: String, CaseIterable, Identifiable, Sendable {
    case markdown, jira, slack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .markdown: "Markdown"
        case .jira: "Jira"
        case .slack: "Slack"
        }
    }

    var help: String {
        switch self {
        case .markdown: "Rewrite as clean Markdown, with headings, lists, and tables"
        case .jira: "Rewrite as Markdown a Jira issue accepts, with action items in place of tables"
        case .slack: "Rewrite as a Slack message, front-loaded and short, ready to paste"
        }
    }

    fileprivate var instructions: String {
        switch self {
        case .markdown:
            """
            Rewrite the user's text as clean, well-organized Markdown. \
            Use headings, bullet and numbered lists, code fences, and tables \
            where the text supports them. Use a table when the text repeats \
            the same fields for several items. \
            Keep every fact, number, and name from the text, and write only \
            what the text already says. \
            Respond with the Markdown alone.
            """
        case .jira:
            """
            Rewrite the user's text as Markdown for a Jira issue. \
            Jira reads these marks: # headings, - and 1. lists, [] action items, \
            ``` code fences, > quotes, **bold**, `code`, and [text](url). \
            Use [] action items for anything checkable. \
            Write anything with aligned columns as a nested list or inside a code fence. \
            Use only the sections the text itself fills. \
            Keep every fact, number, and name from the text, and write only \
            what the text already says. \
            Respond with the Markdown alone.
            """
        case .slack:
            """
            Rewrite the user's text as a Slack message, written in Markdown. \
            Start with the conclusion. Keep each block of prose to two or three \
            lines, and prefer short bullet lists. \
            Write with these marks alone: **bold**, _italic_, - bullets, `code`, \
            ``` code fences, > quotes, and [text](url). \
            Write anything with aligned columns inside a code fence. \
            Keep every fact, number, and name from the text, and write only \
            what the text already says. \
            Respond with the message alone.
            """
        }
    }

    /// Applied to the model's answer. Only Slack needs it: the syntax it wants
    /// collides with the Markdown every model is trained on, so the mechanical
    /// half of that conversion is done here instead of asked for and hoped for.
    fileprivate func styled(_ text: String) -> String {
        self == .slack ? SlackMarkdown.from(text) : text
    }
}

/// Rewrites text as structured Markdown using the on-device Apple
/// Intelligence model. Nothing leaves the machine.
nonisolated enum Organizer {
    static func rewrite(_ text: String, as target: OrganizeTarget) async throws -> String {
        try checkAvailability()
        let session = LanguageModelSession(instructions: target.instructions)
        do {
            return target.styled(unfenced(try await session.respond(to: text).content))
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
