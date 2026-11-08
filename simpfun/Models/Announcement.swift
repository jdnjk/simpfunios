//
//  Announcement.swift
//  simpfun
//

import Foundation

struct Announcement: Decodable, Equatable, Identifiable {
    let serverID: Int?
    let show: Bool
    let title: String
    let text: String
    let createTime: Date?
    let readTimes: Int?

    static let hidden = Announcement(title: "", text: "")

    var id: String {
        serverID.map(String.init) ?? signature
    }

    /// 用内容作为标识，内容变化时重新提示。
    var signature: String { "\(title)\u{1F}\(text)" }

    init(
        serverID: Int? = nil,
        show: Bool = false,
        title: String,
        text: String,
        createTime: Date? = nil,
        readTimes: Int? = nil
    ) {
        self.serverID = serverID
        self.show = show
        self.title = title
        self.text = text
        self.createTime = createTime
        self.readTimes = readTimes
    }

    private enum CodingKeys: String, CodingKey {
        case show
        case title
        case text
        case createTime = "create_time"
        case readTimes = "read_times"
        case serverID = "id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverID = try container.decodeIfPresent(Int.self, forKey: .serverID)
        show = try container.decodeIfPresent(Bool.self, forKey: .show) ?? false
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        readTimes = try container.decodeIfPresent(Int.self, forKey: .readTimes)
        if let rawDate = try container.decodeIfPresent(String.self, forKey: .createTime) {
            createTime = ISO8601Date.parse(rawDate)
        } else {
            createTime = nil
        }
    }

    /// 公告正文带有 HTML 标签，转换为可渲染的 Markdown 文本。
    var markdownText: String {
        var result = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)

        let linkPattern = #"<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>"#
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
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

    var renderedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdownText, options: options)) ?? AttributedString(markdownText)
    }
}

enum ISO8601Date {
    static func parse(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
