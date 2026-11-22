//
//  APILog.swift
//  simpfun
//

import Foundation

/// 网络层调试日志。
///
/// 只关心"不正常"的响应：HTTP 状态码不是 200，或者业务 `code` 不是 200，
/// 都会把请求方法、路径、状态码、服务端提示和响应原文打到 Xcode 控制台，形如：
///
/// ```
/// [API] ✗ POST /api/ins/12/power?action=start → HTTP 200 · code 403 · msg: 实例已有任务队列，禁止操作
///        body: {
///          "code" : 403,
///          "msg" : "实例已有任务队列，禁止操作"
///        }
/// ```
///
/// 需要静音时把 `isEnabled` 置为 `false`。
nonisolated enum APILog {
    static var isEnabled = true

    /// 响应体最多打印的字符数，避免列表接口把控制台刷爆。
    private static let bodyLimit = 2000

    /// 打印一条异常响应。`status` 为 nil 表示没拿到 HTTP 响应（超时、断网等）。
    static func unexpectedResponse(
        _ request: URLRequest,
        status: Int?,
        body: Data? = nil,
        note: String? = nil
    ) {
        guard isEnabled else { return }

        let method = request.httpMethod ?? "GET"
        let envelope = body.flatMap(envelope(from:))

        var head = "[API] ✗ \(method) \(target(of: request)) → "
        head += status.map { "HTTP \($0)" } ?? "无 HTTP 响应"
        if let code = envelope?.code {
            head += " · code \(code)"
        }
        if let msg = envelope?.msg, !msg.isEmpty {
            head += " · msg: \(msg)"
        }
        if let note, !note.isEmpty {
            head += " · \(note)"
        }

        var lines = [head]
        if let body {
            lines.append("       body: \(formatted(body))")
        }
        print(lines.joined(separator: "\n"))
    }

    /// 从响应体里读出 `{ "code": 401, "msg": "..." }` 这类业务信封。
    static func envelope(from data: Data) -> (code: Int, msg: String?)? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let raw = dictionary["code"] else {
            return nil
        }

        let code: Int
        if let value = raw as? Int {
            code = value
        } else if let value = raw as? String, let parsed = Int(value) {
            code = parsed
        } else {
            return nil
        }

        return (code, dictionary["msg"] as? String)
    }

    /// 便于在日志里对照：只保留 path 与 query，域名固定且冗长。
    private static func target(of request: URLRequest) -> String {
        guard let url = request.url else { return "-" }
        var text = url.path
        if let query = url.query, !query.isEmpty {
            text += "?\(query)"
        }
        return text.isEmpty ? "/" : text
    }

    private static func formatted(_ data: Data) -> String {
        guard !data.isEmpty else { return "<空响应体>" }

        var text = String(decoding: data, as: UTF8.self)
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(
               withJSONObject: object,
               options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
           ),
           let prettyText = String(data: pretty, encoding: .utf8) {
            text = prettyText
        }

        if text.count > bodyLimit {
            text = String(text.prefix(bodyLimit)) + "\n…（已截断，共 \(data.count) 字节）"
        }

        // 多行内容缩进对齐，避免和后续日志混在一起。
        return text.replacingOccurrences(of: "\n", with: "\n             ")
    }
}
