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

    /// 跨行延续的 SGR 状态。
    ///
    /// 真实终端里颜色不会被换行重置：日志的 ERROR 行只在行首写一次颜色码，
    /// 后面的堆栈行本身不含任何控制字符，靠“上一行的颜色继续生效”才显示为红色。
    /// 因此逐行解析时必须把状态带到下一行，否则只有带颜色码的那一行会被染色。
    struct SGRState {
        var color: Color = TerminalTextFormatter.defaultColor
        var bold = false
    }

    /// 解析常用的 ANSI SGR 颜色/加粗序列（单行，颜色状态不保留）。
    static func attributed(_ text: String, fontSize: CGFloat = TerminalTextFormatter.fontSize) -> AttributedString {
        var state = SGRState()
        return attributed(text, fontSize: fontSize, state: &state)
    }

    /// 带状态的版本：解析完后把颜色/加粗写回 `state`，供后续行继续使用。
    static func attributed(
        _ text: String,
        fontSize: CGFloat = TerminalTextFormatter.fontSize,
        state: inout SGRState
    ) -> AttributedString {
        var result = AttributedString()
        var color = state.color
        var bold = state.bold
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

        state.color = color
        state.bold = bold
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
        // `ESC[m` 等价于 `ESC[0m`，表示重置。
        let codes: [Int]
        if raw.isEmpty {
            codes = [0]
        } else {
            codes = raw
                .split(separator: ";", omittingEmptySubsequences: false)
                .map { Int($0) ?? 0 }
        }

        var index = 0
        while index < codes.count {
            let code = codes[index]
            var advance = 1

            switch code {
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
                color = ansiColor(for: code - 30)
            case 90...97:
                color = ansiColor(for: code - 90 + 8)
            case 38, 48:
                // 256 色 / 真彩色：38 为前景、48 为背景。
                if let extended = extendedColor(codes, at: index) {
                    if code == 38 {
                        color = extended.color
                    }
                    advance += extended.consumed
                }
            default:
                // 背景色、下划线、斜体等暂不渲染，但参数需要被正确跳过。
                if code == 48, let extended = extendedColor(codes, at: index) {
                    advance += extended.consumed
                }
            }

            index += advance
        }
    }

    /// 解析 `38;5;n` / `38;2;r;g;b` 形式，返回颜色与被消费掉的参数个数。
    private static func extendedColor(_ codes: [Int], at index: Int) -> (color: Color, consumed: Int)? {
        guard index + 1 < codes.count else { return nil }

        switch codes[index + 1] {
        case 5:
            guard index + 2 < codes.count else { return nil }
            return (ansiColor(for: codes[index + 2]), 2)
        case 2:
            guard index + 4 < codes.count else { return nil }
            let red = Double(clamping(codes[index + 2])) / 255
            let green = Double(clamping(codes[index + 3])) / 255
            let blue = Double(clamping(codes[index + 4])) / 255
            return (Color(red: red, green: green, blue: blue), 4)
        default:
            return nil
        }
    }

    private static func clamping(_ value: Int) -> Int {
        min(max(value, 0), 255)
    }

    /// 支持 0–15 基础色与 16–255 的 256 色编号。
    private static func ansiColor(for index: Int) -> Color {
        switch index {
        case 0...15:
            return palette[index]
        case 16...231:
            let value = index - 16
            let steps = [0, 95, 135, 175, 215, 255]
            let red = steps[(value / 36) % 6]
            let green = steps[(value / 6) % 6]
            let blue = steps[value % 6]
            return Color(
                red: Double(red) / 255,
                green: Double(green) / 255,
                blue: Double(blue) / 255
            )
        case 232...255:
            let level = Double(8 + (index - 232) * 10) / 255
            return Color(red: level, green: level, blue: level)
        default:
            return defaultColor
        }
    }

    /// 0–7 为常规色，8–15 为高亮色。
    private static let palette: [Color] = [
        Color(white: 0.55),
        Color(red: 1, green: 0.38, blue: 0.38),
        Color(red: 0.35, green: 1, blue: 0.45),
        Color(red: 1, green: 0.85, blue: 0.3),
        Color(red: 0.45, green: 0.68, blue: 1),
        Color(red: 1, green: 0.5, blue: 1),
        Color(red: 0.4, green: 0.9, blue: 1),
        Color(red: 0.88, green: 0.9, blue: 0.88),
        Color(white: 0.72),
        Color(red: 1, green: 0.5, blue: 0.5),
        Color(red: 0.55, green: 1, blue: 0.6),
        Color(red: 1, green: 0.92, blue: 0.5),
        Color(red: 0.6, green: 0.78, blue: 1),
        Color(red: 1, green: 0.68, blue: 1),
        Color(red: 0.6, green: 0.95, blue: 1),
        Color(white: 1)
    ]
}
