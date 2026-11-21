//
//  AppModel.swift
//  simpfun
//

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum AuthState: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    enum ActiveSheet: Identifiable, Equatable {
        case announcement(Announcement)
        case wechatVerification(message: String)

        var id: String {
            switch self {
            case .announcement(let announcement):
                return "announcement-\(announcement.signature)"
            case .wechatVerification:
                return "wechat-verification"
            }
        }
    }

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    private(set) var authState: AuthState = .restoring
    private(set) var user: UserInfo?
    private(set) var instances: [Instance] = []
    private(set) var isLoadingUser = false
    private(set) var isLoadingInstances = false
    private(set) var hasLoadedUser = false
    private(set) var hasLoadedInstances = false
    private(set) var userErrorMessage: String?
    private(set) var instancesErrorMessage: String?

    var activeSheet: ActiveSheet?
    var notice: Notice?

    private let api: APIClient
    private let tokenStore: TokenStore
    private let defaults: UserDefaults
    private var token: String?
    private var presentedAnnouncement: Announcement?

    private static let dismissedAnnouncementKey = "dismissedAnnouncementSignature"

    init(
        api: APIClient? = nil,
        tokenStore: TokenStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.api = api ?? .shared
        self.tokenStore = tokenStore ?? .shared
        self.defaults = defaults
    }

    // MARK: - Session

    func restoreSession() async {
        guard authState == .restoring else { return }

        guard let storedToken = tokenStore.read() else {
            authState = .signedOut
            return
        }

        token = storedToken
        authState = .signedIn
        await refreshAll()
    }

    func login(username: String, password: String) async throws {
        let newToken = try await api.login(username: username, password: password)
        try tokenStore.save(newToken)

        token = newToken
        authState = .signedIn
        await refreshAll()
    }

    func signOut() {
        tokenStore.delete()
        token = nil
        user = nil
        instances = []
        hasLoadedUser = false
        hasLoadedInstances = false
        userErrorMessage = nil
        instancesErrorMessage = nil
        activeSheet = nil
        notice = nil
        authState = .signedOut
    }

    /// 登录失败时调用，返回需要就地展示的提示；需要弹窗处理的错误返回 nil。
    @discardableResult
    func handleLoginError(_ error: APIError) -> String? {
        switch error {
        case .ipNotVerified(let message), .verificationRequired(let message):
            activeSheet = .wechatVerification(message: message)
            return nil
        case .networkRestricted(let message):
            notice = Notice(title: "网络环境受限", message: message)
            return nil
        default:
            return error.message
        }
    }

    func handleSheetDismissed() {
        guard let announcement = presentedAnnouncement else { return }
        defaults.set(announcement.signature, forKey: Self.dismissedAnnouncementKey)
        presentedAnnouncement = nil
    }

    // MARK: - Data

    func refreshAll() async {
        async let userInfo: Void = refreshUserInfo(force: true)
        async let instanceList: Void = refreshInstances(force: true)
        _ = await (userInfo, instanceList)
    }

    func refreshUserInfo(force: Bool = false) async {
        guard let requestToken = token, !isLoadingUser else { return }
        guard force || !hasLoadedUser else { return }

        isLoadingUser = true
        defer { isLoadingUser = false }

        do {
            let info = try await api.fetchUserInfo(token: requestToken)
            guard token == requestToken else { return }
            user = info
            userErrorMessage = nil
            hasLoadedUser = true
            presentAnnouncementIfNeeded(info.announcement)
        } catch let error as APIError {
            userErrorMessage = handle(error) ?? error.message
        } catch {
            userErrorMessage = error.localizedDescription
        }
    }

    func refreshInstances(force: Bool = false) async {
        guard let requestToken = token, !isLoadingInstances else { return }
        guard force || !hasLoadedInstances else { return }

        isLoadingInstances = true
        defer { isLoadingInstances = false }

        do {
            let list = try await api.fetchInstances(token: requestToken)
            guard token == requestToken else { return }
            instances = list
            instancesErrorMessage = nil
            hasLoadedInstances = true
        } catch let error as APIError {
            instancesErrorMessage = handle(error) ?? error.message
        } catch {
            instancesErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Account actions

    func bindQQ(_ qq: String) async throws {
        try await authorized { token in
            try await api.bindQQ(qq, token: token)
        }
        await refreshUserInfo(force: true)
    }

    func markAnnouncementsRead() async throws {
        try await authorized { token in
            try await api.markAnnouncementsRead(token: token)
        }
    }

    func loadAnnouncements() async throws -> [Announcement] {
        try await api.fetchAnnouncements()
    }

    func loadInviteInfo() async throws -> InviteInfo {
        try await authorized { token in
            try await api.fetchInviteInfo(token: token)
        }
    }

    func loadPointHistory() async throws -> [PointRecord] {
        try await authorized { token in
            try await api.fetchPointHistory(token: token)
        }
    }

    func loadDiamondHistory() async throws -> [DiamondRecord] {
        try await authorized { token in
            try await api.fetchDiamondHistory(token: token)
        }
    }

    // MARK: - Create instance

    func loadGames(custom: Bool) async throws -> [Game] {
        try await authorized { token in
            try await api.fetchGames(custom: custom, token: token)
        }
    }

    func loadGameKinds(gameID: Int, custom: Bool) async throws -> [GameKind] {
        try await authorized { token in
            try await api.fetchGameKinds(gameID: gameID, custom: custom, token: token)
        }
    }

    func loadGameVersions(kindID: Int, custom: Bool) async throws -> [GameVersion] {
        try await authorized { token in
            try await api.fetchGameVersions(kindID: kindID, custom: custom, token: token)
        }
    }

    func loadShopItems(versionID: Int, custom: Bool) async throws -> [ShopItem] {
        try await authorized { token in
            try await api.fetchShopItems(versionID: versionID, custom: custom, token: token)
        }
    }

    func loadConfirmation(
        versionID: Int,
        itemID: Int,
        custom: Bool
    ) async throws -> InstanceConfirmation {
        try await authorized { token in
            try await api.fetchConfirmation(
                versionID: versionID,
                itemID: itemID,
                custom: custom,
                token: token
            )
        }
    }

    func createInstance(versionID: Int, itemID: Int, custom: Bool) async throws {
        try await authorized { token in
            try await api.createInstance(
                versionID: versionID,
                itemID: itemID,
                custom: custom,
                token: token
            )
        }
    }

    // MARK: - Instance detail and tasks

    func loadInstanceDetail(serverID: Int) async throws -> InstanceDetail {
        try await authorized { token in
            try await api.fetchInstanceDetail(serverID: serverID, token: token)
        }
    }

    func loadInstanceTasks(serverID: Int) async throws -> InstanceTasks {
        try await authorized { token in
            try await api.fetchInstanceTasks(serverID: serverID, token: token)
        }
    }

    func promoteInstanceTasks(serverID: Int, taskID: Int) async throws {
        try await authorized { token in
            try await api.promoteInstanceTasks(serverID: serverID, taskID: taskID, token: token)
        }
    }

    func cancelInstanceTask(serverID: Int, taskID: Int) async throws {
        try await authorized { token in
            try await api.cancelInstanceTask(serverID: serverID, taskID: taskID, token: token)
        }
    }

    func loadTerminalConnection(serverID: Int) async throws -> TerminalConnection {
        try await authorized { token in
            try await api.fetchTerminalConnection(serverID: serverID, token: token)
        }
    }

    // MARK: - Private

    /// 为需要登录的请求注入 token，并统一处理登录态失效等错误。
    private func authorized<Value>(_ operation: (String) async throws -> Value) async throws -> Value {
        guard let token else {
            throw APIError.notSignedIn("未登录")
        }

        do {
            return try await operation(token)
        } catch let error as APIError {
            _ = handle(error)
            throw error
        }
    }

    /// 处理需要全局提示的登录态错误；返回需要就地展示的提示。
    private func handle(_ error: APIError) -> String? {
        switch error {
        case .ipNotVerified(let message):
            activeSheet = .wechatVerification(message: message)
            return nil
        case .verificationRequired(let message):
            signOut()
            activeSheet = .wechatVerification(message: message)
            return nil
        case .networkRestricted(let message):
            notice = Notice(title: "网络环境受限", message: message)
            return nil
        case .notSignedIn, .invalidToken:
            signOut()
            notice = Notice(title: "登录已失效", message: error.message)
            return nil
        default:
            return error.message
        }
    }

    private func presentAnnouncementIfNeeded(_ announcement: Announcement) {
        guard announcement.show else { return }
        guard announcement.signature != defaults.string(forKey: Self.dismissedAnnouncementKey) else { return }
        guard activeSheet == nil else { return }

        presentedAnnouncement = announcement
        activeSheet = .announcement(announcement)
    }
}
