//
//  TextSearch.swift
//  simpfun
//

import Foundation

struct FindOptions: Equatable {
    var isCaseSensitive = false
    var isWholeWord = false
    var usesRegularExpression = false
}

/// 查找 / 替换的纯文本逻辑，编辑器视图只负责展示与选区。
enum TextSearch {
    static func ranges(in text: String, query: String, options: FindOptions) -> [NSRange] {
        guard !query.isEmpty, let regex = makeRegex(query: query, options: options) else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        var result: [NSRange] = []
        regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match, match.range.length > 0 else { return }
            result.append(match.range)
        }
        return result
    }

    static func replacingAll(
        in text: String,
        query: String,
        replacement: String,
        options: FindOptions
    ) -> String {
        guard !query.isEmpty, let regex = makeRegex(query: query, options: options) else { return text }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        // 字面量模式下 replacement 里的 `$` 不应被当作模板，先转义。
        let template = options.usesRegularExpression ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template)
    }

    /// 生成用于替换的正则；字面量模式下把查询转义，并支持「全词匹配」。
    private static func makeRegex(query: String, options: FindOptions) -> NSRegularExpression? {
        var pattern = options.usesRegularExpression ? query : NSRegularExpression.escapedPattern(for: query)
        if options.isWholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        let regexOptions: NSRegularExpression.Options = options.isCaseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: regexOptions)
    }
}
