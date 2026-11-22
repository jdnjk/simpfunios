//
//  TextFileModels.swift
//  simpfun
//

import Foundation

// MARK: - 编码

/// 编辑器可选的文本编码。
///
/// 服务端接口以「已解码的字符串」收发内容，所以编码主要影响两件事：
/// 1. 展示与保存时告知用户当前使用哪种编码；
/// 2. 「指定编码重新加载」时把收到的字符按字节回填，再按目标编码重新解码（修复乱码）。
enum TextEncoding: String, CaseIterable, Identifiable {
    case utf8 = "UTF-8"
    case utf16 = "UTF-16"
    case gb18030 = "GB18030"
    case gbk = "GBK"
    case big5 = "Big5"
    case latin1 = "ISO-8859-1"

    var id: String { rawValue }
    var title: String { rawValue }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .utf16:
            return .utf16
        case .gb18030, .gbk:
            // GBK 是 GB18030 的子集，用同一个解码器即可。
            let cf = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        case .big5:
            let cf = CFStringEncoding(CFStringEncodings.big5.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        case .latin1:
            return .isoLatin1
        }
    }

    /// 把字符串的每个字符还原成单字节，再按目标编码重新解码。
    /// 用于「服务端其实按 UTF-8 解了 GBK 文件」这类乱码的还原。
    func reinterpret(_ text: String) -> String? {
        guard let data = text.data(using: .isoLatin1, allowLossyConversion: false) else {
            return nil
        }
        return String(data: data, encoding: stringEncoding)
    }
}

// MARK: - 换行符

enum LineEnding: String, CaseIterable, Identifiable {
    case lf
    case crlf
    case cr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lf:
            return "LF"
        case .crlf:
            return "CRLF"
        case .cr:
            return "CR"
        }
    }

    var sequence: String {
        switch self {
        case .lf:
            return "\n"
        case .crlf:
            return "\r\n"
        case .cr:
            return "\r"
        }
    }

    /// 按出现次数最多的换行符判断文件原本的风格。
    static func detect(in text: String) -> LineEnding {
        var crlf = 0
        var lf = 0
        var cr = 0

        var previousWasCR = false
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\r":
                if previousWasCR { cr += 1 }
                previousWasCR = true
                continue
            case "\n":
                if previousWasCR {
                    crlf += 1
                } else {
                    lf += 1
                }
            default:
                if previousWasCR { cr += 1 }
            }
            previousWasCR = false
        }
        if previousWasCR { cr += 1 }

        if crlf >= lf && crlf >= cr && crlf > 0 { return .crlf }
        if cr > lf && cr > 0 { return .cr }
        return .lf
    }

    /// 编辑器内部统一用 LF，保存/另存时再换成目标风格。
    func applying(to text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard self != .lf else { return normalized }
        return normalized.replacingOccurrences(of: "\n", with: sequence)
    }

    /// 把任意换行风格统一成 LF，供编辑器内部使用。
    static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

// MARK: - 语法

/// 「语法」菜单里可选的解析语言。
///
/// 实际高亮由 Tree-sitter 完成（见 `Utilities/EditorLanguage.swift`），
/// 因此这里只保留有语法包的语言；其余文件（properties、ini、xml、log 等）
/// 按纯文本显示，编辑、查找、换行等能力不受影响。
enum SyntaxLanguage: String, CaseIterable, Identifiable {
    case plain
    case shell
    case json
    case yaml
    case toml
    case java
    case javascript
    case python
    case lua
    case html
    case css
    case markdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "纯文本"
        case .shell: return "Shell"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .java: return "Java"
        case .javascript: return "JavaScript"
        case .python: return "Python"
        case .lua: return "Lua"
        case .html: return "HTML"
        case .css: return "CSS"
        case .markdown: return "Markdown"
        }
    }

    /// 依据文件名推断语法，尽量贴合 Minecraft 服务端的常见文件。
    static func detect(fileName: String) -> SyntaxLanguage {
        let lower = fileName.lowercased()
        let ext = (lower as NSString).pathExtension

        switch ext {
        case "sh", "bash", "zsh", "command": return .shell
        case "json", "json5", "mcmeta": return .json
        case "yml", "yaml": return .yaml
        case "toml": return .toml
        case "java": return .java
        case "js", "mjs", "cjs": return .javascript
        case "py": return .python
        case "lua": return .lua
        case "html", "htm": return .html
        case "css", "scss", "less": return .css
        case "md", "markdown": return .markdown
        default:
            if lower.hasPrefix("start.") || lower.hasPrefix("run.") {
                return .shell
            }
            return .plain
        }
    }
}
