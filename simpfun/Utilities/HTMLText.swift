//
//  HTMLText.swift
//  simpfun
//

import Foundation

enum HTMLText {
    /// 将简单的 HTML 片段（换行、链接）转换为 Markdown。
    static func markdown(from html: String) -> String {
        var result = html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)

        let linkPattern = #"<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>"#
        if let linkRegex = try? NSRegularExpression(
            pattern: linkPattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = linkRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "[$2]($1)")
        }

        let tagPattern = #"<[^>]+>"#
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = tagRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
    }

    static func attributed(_ html: String) -> AttributedString {
        let text = markdown(from: html)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
