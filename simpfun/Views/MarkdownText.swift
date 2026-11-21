//
//  MarkdownText.swift
//  simpfun
//

import Foundation

enum MarkdownText {
    /// 将 Markdown 文本渲染为属性字符串，可限制展示的字数。
    static func attributed(_ text: String, limit: Int? = nil) -> AttributedString {
        var source = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let limit, source.count > limit {
            source = String(source.prefix(limit)) + "…"
        }

        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}
