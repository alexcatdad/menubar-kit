import Foundation

/// Turns `backtick` spans into inline code for `Text`, `StatusHeader` and `PanelNotice`.
///
/// Messages from helpers and CLIs often quote commands or paths in backticks.
/// Only backticks are interpreted, so asterisks, underscores and brackets in
/// paths or error text stay literal (unlike Markdown parsing). An unmatched
/// backtick is kept as text.
public enum InlineCode {
    /// `message` with each backtick-delimited span marked as code (shown monospaced).
    public static func attributed(_ message: String) -> AttributedString {
        let parts = message.split(separator: "`", omittingEmptySubsequences: false)
        // An even number of parts means an odd number of backticks: the last one is unmatched.
        let unmatchedTail = parts.count.isMultiple(of: 2)
        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            let isLast = index == parts.count - 1
            if index.isMultiple(of: 2) {
                result += AttributedString(part)
            } else if unmatchedTail && isLast {
                result += AttributedString("`" + part)
            } else {
                var code = AttributedString(part)
                code.inlinePresentationIntent = .code
                result += code
            }
        }
        return result
    }

    /// `message` without its backticks, for VoiceOver labels and plain-text surfaces.
    public static func plain(_ message: String) -> String {
        String(attributed(message).characters)
    }
}
