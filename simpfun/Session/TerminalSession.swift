//
//  TerminalSession.swift
//  simpfun
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class TerminalSession {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(String)
    }

    struct LogLine: Identifiable {
        let id = UUID()
        let text: AttributedString
    }

    private(set) var state: ConnectionState = .idle
    private(set) var status = ""
    private(set) var stats: TerminalStats?
    private(set) var networkRxDelta: Int?
    private(set) var networkTxDelta: Int?
    private(set) var lines: [LogLine] = []

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var isRefreshingToken = false
    private var hasRequestedLogs = false

    @ObservationIgnored
    var tokenRefresher: (@MainActor () async -> String?)?

    private static let maxLines = 2_000
    private static let welcomeText = "感谢您使用 简幻欢 SFE4.0 和该APP"

    init() {
        appendSystemLine(Self.welcomeText)
    }

    var isReady: Bool {
        state == .connected
    }

    func connect(token: String, url: URL) {
        disconnect()

        lines.removeAll()
        appendSystemLine(Self.welcomeText)

        state = .connecting
        stats = nil
        networkRxDelta = nil
        networkTxDelta = nil
        hasRequestedLogs = false

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        urlSession = session

        let task = session.webSocketTask(with: url)
        webSocket = task
        task.resume()

        send(event: "auth", args: [token])

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(using: task)
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil

        refreshTask?.cancel()
        refreshTask = nil
        isRefreshingToken = false

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        urlSession?.invalidateAndCancel()
        urlSession = nil

        if state == .connecting || state == .connected {
            state = .idle
        }
    }

    func sendCommand(_ command: String) {
        guard isReady else { return }

        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        send(event: "send command", args: command.isEmpty ? [] : [command])
    }

    // MARK: - Socket

    private func receiveLoop(using socket: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()

                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard self.webSocket === socket else { return }
            state = .disconnected(error.localizedDescription)
        }
    }

    /// 处理服务端事件，独立于连接层，便于测试。
    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(TerminalSocketEvent.self, from: data) else {
            return
        }

        switch event.event {
        case "auth success":
            state = .connected
            if !hasRequestedLogs {
                hasRequestedLogs = true
                send(event: "send logs", args: [])
            }

        case "status":
            guard let value = event.args?.first else { return }
            updateStatus(value)

        case "console output":
            guard let output = event.args?.first else { return }
            appendOutput(output)

        case "stats":
            guard let raw = event.args?.first,
                  let statsData = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(TerminalStats.self, from: statsData) else {
                return
            }
            if let previous = stats {
                networkRxDelta = max(0, decoded.networkRxBytes - previous.networkRxBytes)
                networkTxDelta = max(0, decoded.networkTxBytes - previous.networkTxBytes)
            } else {
                networkRxDelta = nil
                networkTxDelta = nil
            }

            stats = decoded
            if !decoded.state.isEmpty {
                updateStatus(decoded.state)
            }

        case "token expiring":
            refreshTokenAndReauth()

        case "jwt error":
            refreshTokenAndReauth()

        default:
            break
        }
    }

    /// 凭证即将过期或已失效时，重新获取 ws token 并在现有连接上重新认证。
    private func refreshTokenAndReauth() {
        guard !isRefreshingToken else { return }

        guard let tokenRefresher else {
            state = .disconnected("终端凭证已过期")
            appendSystemLine(
                "终端凭证已过期，请重新连接。",
                color: Color(red: 1, green: 0.38, blue: 0.38)
            )
            return
        }

        isRefreshingToken = true
        state = .connecting

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let token = await tokenRefresher()

            defer {
                self.isRefreshingToken = false
                self.refreshTask = nil
            }

            guard !Task.isCancelled else { return }

            guard let token, !token.isEmpty else {
                self.appendSystemLine(
                    "终端凭证自动续签失败，请重新连接。",
                    color: Color(red: 1, green: 0.38, blue: 0.38)
                )
                self.state = .disconnected("终端凭证已过期")
                return
            }

            self.send(event: "auth", args: [token])
        }
    }

    private func updateStatus(_ value: String) {
        let previous = status
        status = value

        if value == "offline", previous != "offline" {
            appendSystemLine("服务器已停止。")
        }
    }

    private func send(event: String, args: [String]) {
        guard let webSocket else { return }

        let payload: [String: Any] = ["event": event, "args": args]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        webSocket.send(.string(text)) { [weak self] error in
            guard let error else { return }

            Task { @MainActor [weak self] in
                guard let self, self.webSocket === webSocket else { return }
                self.state = .disconnected(error.localizedDescription)
            }
        }
    }

    // MARK: - Output

    private func appendOutput(_ text: String) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")

        var components = normalized.components(separatedBy: "\n")
        components = components.map { component in
            // 单独的 \r 表示回到行首覆盖输出（如进度条），取最后一次覆盖后的内容。
            guard let lastCarriageReturn = component.lastIndex(of: "\r") else {
                return component
            }
            return String(component[component.index(after: lastCarriageReturn)...])
        }

        while components.first == "" {
            components.removeFirst()
        }
        while components.last == "" {
            components.removeLast()
        }

        for line in components {
            appendLine(line)
        }
    }

    private func appendLine(_ raw: String) {
        let translated = TerminalTextFormatter.translate(raw)
        let display = translated.isEmpty ? " " : translated
        lines.append(LogLine(text: TerminalTextFormatter.attributed(display)))
        trimLines()
    }

    private func appendSystemLine(
        _ text: String,
        color: Color = Color(red: 0.4, green: 0.9, blue: 0.6)
    ) {
        var attributed = AttributedString(text)
        attributed.font = .system(size: 12, weight: .medium, design: .monospaced)
        attributed.foregroundColor = color
        lines.append(LogLine(text: attributed))
        trimLines()
    }

    private func trimLines() {
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }
}
