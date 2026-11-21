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

    // MARK: - 创建实例

    func fetchGames(custom: Bool, token: String) async throws -> [Game] {
        var query: [URLQueryItem] = []
        if custom {
            query.append(URLQueryItem(name: "custom", value: "true"))
        }
        let request = makeRequest(path: "/api/games/list", method: "GET", token: token, query: query)
        let response: GameListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func fetchGameKinds(gameID: Int, custom: Bool, token: String) async throws -> [GameKind] {
        let path = custom ? "/api/games/customlist" : "/api/games/kindlist"
        let request = makeRequest(
            path: path,
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "game_id", value: String(gameID))]
        )
        let response: GameKindListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func fetchGameVersions(kindID: Int, custom: Bool, token: String) async throws -> [GameVersion] {
        let path = custom ? "/api/games/custom_versionlist" : "/api/games/versionlist"
        let request = makeRequest(
            path: path,
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "kind_id", value: String(kindID))]
        )
        let response: GameVersionListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func fetchShopItems(versionID: Int, custom: Bool, token: String) async throws -> [ShopItem] {
        var query = [URLQueryItem(name: "version_id", value: String(versionID))]
        if custom {
            query.append(URLQueryItem(name: "custom", value: "true"))
        }
        let request = makeRequest(path: "/api/shop/list", method: "GET", token: token, query: query)
        let response: ShopItemListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    func fetchConfirmation(
        versionID: Int,
        itemID: Int,
        custom: Bool,
        token: String
    ) async throws -> InstanceConfirmation {
        var query = [
            URLQueryItem(name: "version_id", value: String(versionID)),
            URLQueryItem(name: "item_id", value: String(itemID))
        ]
        if custom {
            query.append(URLQueryItem(name: "custom", value: "true"))
        }
        let request = makeRequest(path: "/api/shop/confirmation", method: "GET", token: token, query: query)
        let response: ConfirmationResponse = try await send(request)
        guard response.code == 200, let data = response.data else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return data
    }

    func createInstance(
        versionID: Int,
        itemID: Int,
        custom: Bool,
        token: String
    ) async throws {
        var form = MultipartFormData()
        form.append(String(itemID), for: "item_id")
        form.append(String(versionID), for: "version_id")
        if custom {
            form.append("true", for: "custom")
        }

        let response: ActionResponse = try await sendForm(path: "/api/ins/create", form: form, token: token)
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    // MARK: - 实例详情与任务

    func fetchInstanceDetail(serverID: Int, token: String) async throws -> InstanceDetail {
        let request = makeRequest(path: "/api/ins/\(serverID)/detail", method: "GET", token: token)
        let response: InstanceDetailResponse = try await send(request)
        guard response.code == 200, let data = response.data else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return data
    }

    func fetchInstanceTasks(serverID: Int, token: String) async throws -> InstanceTasks {
        let request = makeRequest(path: "/api/ins/\(serverID)/tasks", method: "GET", token: token)
        let response: InstanceTasksResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return InstanceTasks(
            list: list,
            running: response.running ?? 0,
            waiting: response.waiting ?? 0,
            numFirstWaiting: response.numFirstWaiting ?? 0,
            runningPro: response.runningPro ?? 0,
            waitingPro: response.waitingPro ?? 0,
            numFirstWaitingPro: response.numFirstWaitingPro ?? -1,
            isPro: response.isPro ?? false
        )
    }

    func promoteInstanceTasks(serverID: Int, taskID: Int, token: String) async throws {
        var form = MultipartFormData()
        form.append(String(taskID), for: "task_id")

        let response: ActionResponse = try await sendForm(
            path: "/api/ins/\(serverID)/tasks",
            method: "PUT",
            form: form,
            token: token
        )
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    func cancelInstanceTask(serverID: Int, taskID: Int, token: String) async throws {
        var form = MultipartFormData()
        form.append(String(taskID), for: "task_id")

        let response: ActionResponse = try await sendForm(
            path: "/api/ins/\(serverID)/tasks",
            form: form,
            token: token
        )
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    func fetchTerminalConnection(serverID: Int, token: String) async throws -> TerminalConnection {
        let request = makeRequest(path: "/api/ins/\(serverID)/ws", method: "GET", token: token)
        let response: TerminalConnectionResponse = try await send(request)
        guard response.code == 200, let data = response.data else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return data
    }

    private func makeRequest(
        path: String,
        method: String,
        token: String? = nil,
        query: [URLQueryItem] = []
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }

        var request = URLRequest(url: components.url!)
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
        method: String = "POST",
        form: MultipartFormData,
        token: String? = nil
    ) async throws -> Response {
        var request = makeRequest(path: path, method: method, token: token)
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

private struct GameListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [Game]?
}

private struct GameKindListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [GameKind]?
}

private struct GameVersionListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [GameVersion]?
}

private struct ShopItemListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [ShopItem]?
}

private struct ConfirmationResponse: Decodable {
    let code: Int
    let msg: String?
    let data: InstanceConfirmation?
}

private struct InstanceDetailResponse: Decodable {
    let code: Int
    let msg: String?
    let data: InstanceDetail?
}

private struct InstanceTasksResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [InstanceTask]?
    let running: Int?
    let waiting: Int?
    let numFirstWaiting: Int?
    let runningPro: Int?
    let waitingPro: Int?
    let numFirstWaitingPro: Int?
    let isPro: Bool?

    private enum CodingKeys: String, CodingKey {
        case code
        case msg
        case list
        case running
        case waiting
        case isPro = "is_pro"
        case numFirstWaiting = "num_first_waiting"
        case runningPro = "running_pro"
        case waitingPro = "waiting_pro"
        case numFirstWaitingPro = "num_first_waiting_pro"
    }
}

private struct TerminalConnectionResponse: Decodable {
    let code: Int
    let msg: String?
    let data: TerminalConnection?
}

private struct ErrorEnvelope: Decodable {
    let code: Int
    let msg: String?
}
