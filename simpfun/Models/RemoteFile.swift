//
//  RemoteFile.swift
//  simpfun
//

import Foundation

/// 实例文件目录中的一项，`file == true` 表示文件，否则是文件夹。
struct RemoteFile: Identifiable, Hashable, Decodable {
    let name: String
    let isFile: Bool
    let size: Int?
    let mime: String?
    /// 服务端格式：`2026-11-22 10:24:34`。
    let modifiedAt: String?

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case size
        case mime
        case isFile = "file"
        case modifiedAt = "modified_at"
    }

    /// 目录里偶尔会出现缺字段的条目（例如没有 `file` 或 `size` 是字符串），
    /// 这里放宽解码，避免一条异常数据让整个目录加载失败。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isFile = (try? container.decodeIfPresent(Bool.self, forKey: .isFile)) ?? false

        if let value = try? container.decodeIfPresent(Int.self, forKey: .size) {
            size = value
        } else if let text = try? container.decodeIfPresent(String.self, forKey: .size) {
            size = Int(text)
        } else {
            size = nil
        }

        mime = try? container.decodeIfPresent(String.self, forKey: .mime)
        modifiedAt = try? container.decodeIfPresent(String.self, forKey: .modifiedAt)
    }

    /// 拼接为服务端使用的绝对路径，例如 `/plugins/x.jar`。
    func path(in directory: String) -> String {
        RemotePath.join(directory, name)
    }

    /// 能否在应用内编辑：`text/*` 或常见的文本扩展名。
    var isEditable: Bool {
        guard isFile else { return false }

        let lowerMime = (mime ?? "").lowercased()
        if lowerMime.hasPrefix("text/") { return true }
        if lowerMime.contains("json") || lowerMime.contains("xml") || lowerMime.contains("yaml") {
            return true
        }

        let ext = (name as NSString).pathExtension.lowercased()
        return Self.editableExtensions.contains(ext) || name.lowercased().hasPrefix("start.")
    }

    private static let editableExtensions: Set<String> = [
        "txt", "text", "log", "md", "markdown",
        "sh", "bash", "zsh", "command", "bat", "cmd",
        "properties", "env", "conf", "cfg", "ini", "toml",
        "json", "json5", "mcmeta", "yml", "yaml",
        "java", "js", "mjs", "cjs", "ts", "tsx", "py", "lua", "rb", "php", "go", "rs",
        "xml", "plist", "html", "htm", "css", "scss", "sql", "csv", "tsv",
        "gradle", "gitignore", "editorconfig"
    ]
}

/// 压缩格式，接口只接受 `7z` 与 `zip`。
enum ArchiveFormat: String, CaseIterable, Identifiable {
    case sevenZip = "7z"
    case zip = "zip"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// 新建条目的类型。
enum FileCreateMode: String, Identifiable {
    case file
    case folder

    var id: String { rawValue }
    var title: String { self == .file ? "新建文件" : "新建文件夹" }
}

/// 服务端路径都是 `/` 分隔的绝对路径，这里集中处理拼接与拆分。
enum RemotePath {
    static func join(_ directory: String, _ name: String) -> String {
        let base = normalized(directory)
        return base == "/" ? "/\(name)" : "\(base)/\(name)"
    }

    /// `/plugins/x.jar` → `/plugins`
    static func parent(of path: String) -> String {
        let trimmed = normalized(path)
        guard let index = trimmed.lastIndex(of: "/"), index != trimmed.startIndex else {
            return "/"
        }
        return String(trimmed[..<index])
    }

    /// `/plugins/x.jar` → `x.jar`
    static func lastComponent(_ path: String) -> String {
        let trimmed = normalized(path)
        guard let index = trimmed.lastIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: index)...])
    }

    /// 部分接口要求目录以 `/` 结尾（例如新建文件时的 `root`）。
    static func directoryForm(_ path: String) -> String {
        let trimmed = normalized(path)
        return trimmed == "/" ? "/" : "\(trimmed)/"
    }

    /// 去掉多余的尾部斜杠，根目录保持 `/`。
    static func normalized(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return "/" }
        if !value.hasPrefix("/") { value = "/" + value }
        while value.count > 1, value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
