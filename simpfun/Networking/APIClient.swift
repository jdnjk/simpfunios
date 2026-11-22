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

    /// 电源操作：`GET /api/ins/{id}/power?action=start|stop|restart|kill`。
    /// 成功时服务端返回 `{"code": 200, "status": true, "msg": "成功开启服务器"}`。
    func powerAction(_ action: InstancePowerAction, serverID: Int, token: String) async throws {
        let request = makeRequest(
            path: "/api/ins/\(serverID)/power",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "action", value: action.rawValue)]
        )

        let response: PowerResponse = try await send(request)
        if response.code == 200, response.status != false {
            return
        }
        if response.code == 200 {
            let message = response.msg ?? "操作未成功，请稍后重试。"
            // code 是 200 但 status 为 false，同样属于"指令没被接受"，一并打日志。
            APILog.unexpectedResponse(request, status: 200, note: "status = false · msg: \(message)")
            throw APIError.requestRejected(message)
        }
        throw APIError.make(code: response.code, message: response.msg)
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

    // MARK: - 文件管理

    /// 列出目录内容：`GET /api/ins/{id}/file/list?path=/`。
    func fetchFileList(serverID: Int, path: String, token: String) async throws -> [RemoteFile] {
        let request = makeRequest(
            path: "/api/ins/\(serverID)/file/list",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "path", value: path)]
        )
        let response: FileListResponse = try await send(request)
        guard response.code == 200, let list = response.list else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return list
    }

    /// 解压：`root` 为所在目录，`file` 为该目录下的文件名（不带路径）。
    func unarchiveFile(serverID: Int, root: String, file: String, token: String) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/unarchive",
            values: [("root", root), ("file", file)],
            token: token
        )
    }

    /// 压缩：`files` 为目录内的名称数组，`root` 为它们所在的目录。
    func archiveFiles(
        serverID: Int,
        root: String,
        files: [String],
        format: ArchiveFormat,
        token: String
    ) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/archive",
            values: [
                ("root", root),
                ("files", Self.jsonArray(files)),
                ("format", format.rawValue)
            ],
            token: token
        )
    }

    /// 删除：`list` 为绝对路径的 JSON 数组。
    func deleteFiles(serverID: Int, paths: [String], token: String) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/delete",
            values: [("list", Self.jsonArray(paths))],
            token: token
        )
    }

    /// 修复中文乱码与文件权限。
    func fixFilePermissionAndCharset(serverID: Int, token: String) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/toolbox",
            values: [("action", "fix_permission_and_charset")],
            token: token
        )
    }

    /// 下载：先取临时直链，再由界面交给浏览器/分享。
    func fetchFileDownloadLink(serverID: Int, path: String, token: String) async throws -> URL {
        let request = makeRequest(
            path: "/api/ins/\(serverID)/file/download",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "path", value: path)]
        )
        let response: FileDownloadResponse = try await send(request)
        guard response.code == 200,
              let link = response.link,
              let url = URL(string: link) else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return url
    }

    /// 读取文本文件内容：`/api/ins/{id}/file/fetch?path=/start.sh`。
    func fetchFileContent(serverID: Int, path: String, token: String) async throws -> String {
        let request = makeRequest(
            path: "/api/ins/\(serverID)/file/fetch",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "path", value: path)]
        )
        let response: FileContentResponse = try await send(request)
        guard response.code == 200, let content = response.content else {
            throw APIError.make(code: response.code, message: response.msg)
        }
        return content
    }

    /// 保存文本文件：表单 `path` + `content`，成功返回 `{"code":200,"msg":"success"}`。
    func saveFileContent(serverID: Int, path: String, content: String, token: String) async throws {
        let response: ActionResponse = try await sendFormValues(
            path: "/api/ins/\(serverID)/file/save",
            values: [("path", path), ("content", content)],
            token: token
        )
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    /// 粘贴（剪切后的移动）：`list` 为绝对路径，`target` 为目标目录。
    ///
    /// 官方 curl 写的是 `GET` + 表单体（`--request GET --data-urlencode`），
    /// 但服务端未必会解析 GET 的请求体，所以先按查询参数发 GET；
    /// 若网关明确不认这个方法（404/405/HTML 页面），再用 POST 表单补一次。
    func pasteFiles(serverID: Int, paths: [String], target: String, token: String) async throws {
        let path = "/api/ins/\(serverID)/file/paste"
        let list = Self.jsonArray(paths)

        let request = makeRequest(
            path: path,
            method: "GET",
            token: token,
            query: [
                URLQueryItem(name: "list", value: list),
                URLQueryItem(name: "target", value: target)
            ]
        )

        do {
            let response: ActionResponse = try await send(request)
            guard response.code == 200 else {
                throw APIError.make(code: response.code, message: response.msg)
            }
        } catch {
            guard Self.isMethodMismatch(error) else { throw error }
            try await sendFileAction(
                path: path,
                values: [("list", list), ("target", target)],
                token: token
            )
        }
    }

    /// 判断错误是否更像「这个路径/方法不存在」，而不是业务拒绝。
    private static func isMethodMismatch(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .server(let code, _):
            return code == 404 || code == 405
        case .invalidResponse:
            return true
        default:
            return false
        }
    }

    /// 创建副本（仅文件）。
    func copyFile(serverID: Int, location: String, token: String) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/copy",
            values: [("location", location)],
            token: token
        )
    }

    /// 重命名，`origin` 与 `target` 都是绝对路径。
    func renameFile(serverID: Int, origin: String, target: String, token: String) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/rename",
            values: [("origin", origin), ("target", target)],
            token: token
        )
    }

    /// 新建文件或文件夹。
    func createFileEntry(
        serverID: Int,
        mode: FileCreateMode,
        root: String,
        name: String,
        token: String
    ) async throws {
        try await sendFileAction(
            path: "/api/ins/\(serverID)/file/create",
            values: [("mode", mode.rawValue), ("root", root), ("name", name)],
            token: token
        )
    }

    /// 文件类接口统一使用 `application/x-www-form-urlencoded`（与官方 curl 示例一致），
    /// 只关心 `code`，其余提示交给界面。
    private func sendFileAction(
        path: String,
        method: String = "POST",
        values: [(String, String)],
        token: String
    ) async throws {
        let response: ActionResponse = try await sendFormValues(
            path: path,
            method: method,
            values: values,
            token: token
        )
        guard response.code == 200 else {
            throw APIError.make(code: response.code, message: response.msg)
        }
    }

    private static func jsonArray(_ values: [String]) -> String {
        let encoder = JSONEncoder()
        // 服务端示例是原样斜杠（`["/plugins/a.jar"]`），不做 `\/` 转义。
        encoder.outputFormatting = [.withoutEscapingSlashes]

        guard let data = try? encoder.encode(values),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
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

    /// 以 `application/x-www-form-urlencoded` 提交，部分接口（文件管理、工具箱）只接受这种格式。
    private func sendFormValues<Response: Decodable>(
        path: String,
        method: String = "POST",
        values: [(String, String)],
        token: String? = nil,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        var request = makeRequest(path: path, method: method, token: token, query: query)
        request.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Self.formEncoded(values)
        return try await send(request)
    }

    private static func formEncoded(_ values: [(String, String)]) -> Data {
        // RFC 3986 未保留字符之外一律百分号编码；空格用 %20，服务端同样能解析。
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        let text = values.map { name, value in
            let key = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encoded)"
        }
        .joined(separator: "&")

        return Data(text.utf8)
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
            Self.log(request, status: nil, note: "请求失败：\(error.localizedDescription)")
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            Self.log(request, status: nil, body: data, note: "响应不是 HTTP 响应")
            throw APIError.invalidResponse
        }

        do {
            let value = try decoder.decode(Response.self, from: data)
            // 业务错误也是 HTTP 200 + `{"code": 403, ...}`，解码能通过，
            // 真正抛错发生在调用方，所以这里先按业务码兜一次日志。
            let businessCode = APILog.envelope(from: data)?.code
            if http.statusCode != 200 || (businessCode != nil && businessCode != 200) {
                Self.log(request, status: http.statusCode, body: data)
            }
            return value
        } catch {
            Self.log(
                request,
                status: http.statusCode,
                body: data,
                note: "响应无法解码：\(error.localizedDescription)"
            )
            // 业务错误同样以 JSON 返回，尽量把服务端的提示展示给用户。
            if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
                throw APIError.make(code: envelope.code, message: envelope.msg)
            }
            // 网关或反向代理异常时会返回 HTML（例如 404 Not Found 页面）或空响应体。
            if http.statusCode >= 400 {
                throw APIError.server(
                    code: http.statusCode,
                    message: "服务器返回异常（HTTP \(http.statusCode)），请稍后重试。"
                )
            }
            throw APIError.invalidResponse
        }
    }

    /// 只打印非 200 的响应，正常请求不打扰控制台。
    private static func log(
        _ request: URLRequest,
        status: Int?,
        body: Data? = nil,
        note: String? = nil
    ) {
        APILog.unexpectedResponse(request, status: status, body: body, note: note)
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

/// 电源接口额外返回 `status` 表示指令是否被接受。
private struct PowerResponse: Decodable {
    let code: Int
    let status: Bool?
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

private struct FileListResponse: Decodable {
    let code: Int
    let msg: String?
    let list: [RemoteFile]?
}

private struct FileDownloadResponse: Decodable {
    let code: Int
    let msg: String?
    let link: String?
}

private struct FileContentResponse: Decodable {
    let code: Int
    let msg: String?
    let content: String?
}
