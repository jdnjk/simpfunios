//
//  APIError.swift
//  simpfun
//

import Foundation

/// 服务端统一返回 `code` 与 `msg`，这里将业务状态码映射为应用内错误。
enum APIError: Error, Equatable {
    /// 表单校验失败、账号密码错误、QQ 已被绑定等业务提示。
    case requestRejected(String)
    /// 当前 IP 不在白名单，需要先在微信小程序中完成验证。
    case ipNotVerified(String)
    /// 当前网络运营商不在允许范围内。
    case networkRestricted(String)
    /// 未登录。
    case notSignedIn(String)
    /// Token 无效。
    case invalidToken(String)
    /// 需要重新进行小程序验证，或账号已在其它设备退出登录。
    case verificationRequired(String)
    /// 当前账号没有权限执行该操作。
    case forbidden(String)
    /// 积分不足。
    case insufficientPoints(String)
    /// 请求过于频繁。
    case rateLimited(String)
    case server(code: Int, message: String)
    case network(String)
    case invalidResponse

    var message: String {
        switch self {
        case .requestRejected(let message),
             .ipNotVerified(let message),
             .networkRestricted(let message),
             .notSignedIn(let message),
             .invalidToken(let message),
             .verificationRequired(let message),
             .forbidden(let message),
             .insufficientPoints(let message),
             .rateLimited(let message):
            return message
        case .server(_, let message):
            return message
        case .network:
            return "无法连接服务器，请检查网络后重试。"
        case .invalidResponse:
            return "服务器返回了无法识别的内容，请稍后重试。"
        }
    }

    static func make(code: Int, message: String?) -> APIError {
        let message = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch code {
        case 400:
            if message == "账号验证失败" {
                return .invalidToken(message)
            }
            return .requestRejected(message.isEmpty ? "请求未能完成，请稍后重试。" : message)
        case 401:
            if message.contains("白名单") || message.contains("小程序") {
                return .ipNotVerified(message)
            }
            if message.contains("运营商") || message.contains("不在允许范围") {
                return .networkRestricted(message)
            }
            return .notSignedIn(message.isEmpty ? "登录状态已失效，请重新登录。" : message)
        case 402:
            return .insufficientPoints(message.isEmpty ? "积分不足，无法完成操作。" : message)
        case 403:
            if message.contains("账号验证失败") {
                return .verificationRequired(message)
            }
            return .forbidden(message.isEmpty ? "没有权限执行该操作。" : message)
        case 429:
            return .rateLimited(message.isEmpty ? "操作过于频繁，请稍后再试。" : message)
        default:
            return .server(code: code, message: message.isEmpty ? "请求失败（\(code)）" : message)
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? { message }
}
