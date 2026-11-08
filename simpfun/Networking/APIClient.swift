//
//  APIClient.swift
//  simpfun
//

import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL = URL(string: "https://api.simpfun.cn")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func login(username: String, password: String) async throws -> String {
        var form = MultipartFormData()
        form.append(username, for: "username")
        form.append(password, for: "passwd")

        let response: LoginResponse = try await sendForm(path: "/api/auth/login", form: form)
        guard response.code == 200, let token = response.token, !token.isEmpty else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return token
    }

    func fetchUserInfo(token: String) async throws -> UserInfo {
        let request = makeRequest(path: "/api/auth/info", method: "GET", token: token)
        let response: UserInfoResponse = try await send(request)
        guard response.code == 200, let info = response.info else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return info
    }

    func fetchInstances(token: String) async throws -> [Instance] {
        let request = makeRequest(path: "/api/ins/list", method: "GET", token: token)
        let response: InstanceListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func bindQQ(_ qq: String, token: String) async throws {
        var form = MultipartFormData()
        form.append(qq, for: "qq")

        let response: ActionResponse = try await sendForm(path: "/api/bindqq", form: form, token: token)
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let request = makeRequest(path: "/api/announcement", method: "GET")
        let response: AnnouncementListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func markAnnouncementsRead(token: String) async throws {
        let request = makeRequest(path: "/api/announcement_read", method: "POST", token: token)
        let response: ActionResponse = try await send(request)

        if response.code == 200 { return }
        if response.code == 400, response.msg == "已经阅读过公告了" { return }
        throw APIError.make(code: response.code, message: response.msg)
    }

    func fetchInviteInfo(token: String) async throws -> InviteInfo {
        let request = makeRequest(path: "/api/invite", method: "GET", token: token)
        let response: InviteResponse = try await send(request)
        guard response.code == 200, let data = response.data else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return data
    }

    func fetchPointHistory(token: String) async throws -> [PointRecord] {
        let request = makeRequest(path: "/api/pointhistory", method: "GET", token: token)
        let response: PointHistoryResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func fetchDiamondHistory(token: String) async throws -> [DiamondRecord] {
        let request = makeRequest(path: "/api/diamondhistory", method: "GET", token: token)
        let response: DiamondHistoryResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    private func makeRequest(path: String, method: String, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func sendForm<Response: Decodable>(
        path: String,
        form: MultipartFormData,
        token: String? = nil
    ) async throws -> Response {
        var request = makeRequest(path: path, method: "POST", token: token)
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.encoded()
        return try await send(request)
    }

    /// 与 Android 端保持一致的标识：SimpfunAPP/版本号。
    private static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "SimpfunAPP/\(version)"
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard response is HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            // 业务错误同样以 JSON 返回，尽量把服务端的提示展示给用户。
            if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
                throw APIError.make(code: envelope.code, message: envelope.msg)
            }
            throw APIError.invalidResponse
        }
    }
}

private struct LoginResponse: Decodable {
    let code: Int
    let msg: String?
    let token: String?
}

private struct UserInfoResponse: Decodable {
    let code: Int
    let msg: String?
    let info: UserInfo?
}

private struct InstanceListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [Instance]?
}

private struct ActionResponse: Decodable {
    let code: Int
    let msg: String?
}

private struct AnnouncementListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [Announcement]?
}

private struct InviteResponse: Decodable {
    let code: Int
    let msg: String?
    let data: InviteInfo?
}

private struct PointHistoryResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [PointRecord]?
}

private struct DiamondHistoryResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [DiamondRecord]?
}

private struct ErrorEnvelope: Decodable {
    let code: Int
    let msg: String?
}
