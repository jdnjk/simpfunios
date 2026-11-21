//
//  TerminalTextFormatter.swift
//  simpfun
//

import Foundation
import SwiftUI

enum TerminalTextFormatter {
    private static let escape = Character("\u{001B}")
    private static let defaultColor = Color(red: 0.88, green: 0.9, blue: 0.88)
    private static let fontSize: CGFloat = 12

    /// 将 Pterodactyl 守护进程提示替换为简幻欢的提示文案。
    /// 日志中通常带有 ANSI 颜色码，匹配前先去掉控制字符并归一化空白。
    static func translate(_ text: String) -> String {
        let plain = normalizedPlainText(text)
        var result = plain
        var didTranslate = false

        let mappings: [(source: String, target: String)] = [
            (
                "Checking server disk space usage, this could take a few seconds...",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 正在检查磁盘占用情况，请稍等...\u{001B}[0m"
            ),
            (
                "Updating process configuration files...",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 已自动更新服务器端口等信息！\u{001B}[0m"
            ),
            (
                "Pulling Docker container image, this could take a few minutes to complete...",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 正在拉取Docker镜像，请稍等...\u{001B}[0m"
            ),
            (
                "Finished pulling Docker container image",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 已完成Docker镜像拉取！\u{001B}[0m"
            ),
            (
                "Server is outputting console data too quickly -- throttling...",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 服务器输出控制台数据过快 -- 限流中...\u{001B}[0m"
            ),
            (
                "Aborting automatic restart, crash detection is disabled for this instance.",
                "\u{001B}[33m\u{001B}[1m[简幻欢]:\u{001B}[39m 服务器已停止运行，请检查启动脚本和服务端配置文件\u{001B}[0m"
            )
        ]

        for mapping in mappings {
            if result.contains(mapping.source) {
                result = result.replacingOccurrences(of: mapping.source, with: mapping.target)
                didTranslate = true
            }
        }

        guard didTranslate else {
            return text
        }

        result = result.replacingOccurrences(of: "[Pterodactyl Daemon]:", with: "\n")
        result = result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return result
    }

    private static func normalizedPlainText(_ text: String) -> String {
        var plain = text

        let ansiPattern = "\u{001B}\\[[0-9;]*[A-Za-z]"
        if let regex = try? NSRegularExpression(pattern: ansiPattern) {
            let range = NSRange(plain.startIndex..., in: plain)
            plain = regex.stringByReplacingMatches(in: plain, range: range, withTemplate: "")
        }

        return plain.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// 解析常用的 ANSI SGR 颜色/加粗序列。
    static func attributed(_ text: String, fontSize: CGFloat = TerminalTextFormatter.fontSize) -> AttributedString {
        var result = AttributedString()
        var color = defaultColor
        var bold = false
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == escape {
                let afterEscape = text.index(after: index)

                if afterEscape < text.endIndex, text[afterEscape] == "[" {
                    if let finalIndex = csiFinalByteIndex(in: text, from: text.index(after: afterEscape)) {
                        if text[finalIndex] == "m" {
                            let codeStart = text.index(afterEscape, offsetBy: 1)
                            applySGR(
                                String(text[codeStart..<finalIndex]),
                                color: &color,
                                bold: &bold
                            )
                        }

                        index = text.index(after: finalIndex)
                        continue
                    }
                }

                index = afterEscape
                continue
            }

            let nextEscape = text[index...].firstIndex(of: escape) ?? text.endIndex
            let segment = String(text[index..<nextEscape])

            if !segment.isEmpty {
                var piece = AttributedString(segment)
                piece.font = .system(
                    size: fontSize,
                    weight: bold ? .bold : .regular,
                    design: .monospaced
                )
                piece.foregroundColor = color
                result.append(piece)
            }

            index = nextEscape
        }

        return result
    }

    private static func csiFinalByteIndex(in text: String, from start: String.Index) -> String.Index? {
        var index = start

        while index < text.endIndex {
            if let scalar = text[index].unicodeScalars.first,
               scalar.value >= 0x40, scalar.value <= 0x7E {
                return index
            }
            index = text.index(after: index)
        }

        return nil
    }

    private static func applySGR(_ raw: String, color: inout Color, bold: inout Bool) {
        let codes = raw
            .split(separator: ";", omittingEmptySubsequences: false)
            .compactMap { Int($0) }

        guard !codes.isEmpty else {
            color = defaultColor
            bold = false
            return
        }

        var index = 0
        while index < codes.count {
            switch codes[index] {
            case 0:
                color = defaultColor
                bold = false
            case 1:
                bold = true
            case 22:
                bold = false
            case 39:
                color = defaultColor
            case 30...37:
                color = ansiColor(for: codes[index] - 30)
            case 90...97:
                color = ansiColor(for: codes[index] - 90)
            case 38, 48:
                // 256 色/真彩色序列，当前不解析。
                return
            default:
                break
            }

            index += 1
        }
    }

    private static func ansiColor(for index: Int) -> Color {
        switch index {
        case 0:
            return Color(white: 0.55)
        case 1:
            return Color(red: 1, green: 0.38, blue: 0.38)
        case 2:
            return Color(red: 0.35, green: 1, blue: 0.45)
        case 3:
            return Color(red: 1, green: 0.85, blue: 0.3)
        case 4:
            return Color(red: 0.45, green: 0.68, blue: 1)
        case 5:
            return Color(red: 1, green: 0.5, blue: 1)
        case 6:
            return Color(red: 0.4, green: 0.9, blue: 1)
        default:
            return defaultColor
        }
    }
}
