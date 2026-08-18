import Foundation

/// Best-effort guess at what the scratchpad holds. It drives the status-bar
/// label and decides which commands stay enabled, so it is deliberately
/// conservative: prose matches nothing, and matching nothing enables
/// everything. Only a positive identification takes commands away.
nonisolated enum ContentKind: String, CaseIterable, Sendable {
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case jwt = "JWT"
    case timestamp = "Unix timestamp"
    case isoDate = "ISO 8601 date"
    case hex = "Hex"
    case base64 = "Base64"
    case url = "URL"

    var label: String { rawValue }

    /// Parsing every keystroke of a very large paste would cost more than the
    /// label is worth, so past this size we simply do not guess.
    private static let sizeLimit = 200_000

    /// Checks run most specific first; the first match wins.
    static func detect(_ text: String) -> ContentKind? {
        guard text.utf8.count <= sizeLimit else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isJWT(trimmed) { return .jwt }
        if isJSON(trimmed) { return .json }
        if let markup = markupKind(trimmed) { return markup }
        if isTimestamp(trimmed) { return .timestamp }
        if isISODate(trimmed) { return .isoDate }
        if isHex(trimmed) { return .hex }
        if isBase64(trimmed) { return .base64 }
        if isURL(trimmed) { return .url }
        return nil
    }

    /// Three dot-separated base64url segments opening with an encoded `{"`.
    private static func isJWT(_ text: String) -> Bool {
        text.hasPrefix("eyJ") && text.wholeMatch(of: /[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/) != nil
    }

    private static func isJSON(_ text: String) -> Bool {
        guard text.hasPrefix("{") || text.hasPrefix("[") else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
    }

    private static func markupKind(_ text: String) -> ContentKind? {
        guard text.hasPrefix("<"), text.hasSuffix(">") else { return nil }
        let opening = text.prefix(15).lowercased()
        return opening.hasPrefix("<!doctype html") || opening.hasPrefix("<html") ? .html : .xml
    }

    /// Ten digits is Unix seconds since 2001, nineteen is nanoseconds until
    /// 2262, so the window spans every unit the Timestamp submenu offers. It
    /// also catches long numeric ids, which costs nothing: the label is a
    /// guess, and every operation those ids might want stays enabled.
    private static func isTimestamp(_ text: String) -> Bool {
        (10...19).contains(text.utf8.count) && text.allSatisfy(\.isNumber)
    }

    private static func isISODate(_ text: String) -> Bool {
        text.wholeMatch(of: /\d{4}-\d{2}-\d{2}([T ][\d:.]+(Z|[+-]\d{2}:?\d{2})?)?/) != nil
    }

    /// An even count of at least 8 hex digits, whitespace ignored. At least
    /// one letter is required so a run of digits is not called hex.
    private static func isHex(_ text: String) -> Bool {
        let digits = text.filter { !$0.isWhitespace }
        return digits.count >= 8 && digits.count.isMultiple(of: 2)
            && digits.allSatisfy(\.isHexDigit) && digits.contains(where: \.isLetter)
    }

    /// Base64 charset with valid padding length. A digit plus mixed case, or
    /// explicit `=` padding, is required so an ordinary long word does not
    /// qualify.
    private static func isBase64(_ text: String) -> Bool {
        let chars = text.filter { !$0.isWhitespace }
        guard chars.count >= 16, chars.count.isMultiple(of: 4),
              chars.wholeMatch(of: /[A-Za-z0-9+\/]+={0,2}/) != nil else { return false }
        return chars.hasSuffix("=")
            || (chars.contains(where: \.isNumber)
                && chars.contains(where: \.isUppercase) && chars.contains(where: \.isLowercase))
    }

    private static func isURL(_ text: String) -> Bool {
        !text.contains(where: \.isWhitespace) && text.contains("://") && URL(string: text) != nil
    }
}
