//
//  InstanceTerminalFeatureView.swift
//  simpfun
//

import SwiftUI

struct InstanceTerminalFeatureView: View {
    let instanceID: Int
    let onRequireTasks: () -> Void

    @Environment(AppModel.self) private var model
    @State private var session = TerminalSession()
    @State private var command = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let errorMessage {
                errorView(errorMessage)
            } else {
                terminalView
            }
        }
        .task {
            session.tokenRefresher = {
                do {
                    let connection = try await model.loadTerminalConnection(serverID: instanceID)
                    return connection.token
                } catch let error as APIError {
                    if case .forbidden(let message) = error, message.contains("任务队列") {
                        onRequireTasks()
                    }
                    return nil
                } catch {
                    return nil
                }
            }
            await connect()
        }
        .onDisappear {
            session.disconnect()
        }
    }

    // MARK: - Terminal

    private var terminalView: some View {
        VStack(spacing: 0) {
            header
            console
        }
        .background(Color(white: 0.06))
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                statusBadge
                connectionBadge

                Spacer(minLength: 8)

                if case .disconnected = session.state {
                    Button("重连") {
                        Task { await connect() }
                    }
                    .font(.footnote.weight(.medium))
                }
            }

            if let stats = session.stats {
                statsRow(stats)
            } else {
                Text("等待统计数据…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var connectionBadge: some View {
        switch session.state {
        case .idle:
            Text("未连接")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .connecting:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("连接中")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .connected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("已连接")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .disconnected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                Text("已断开")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func statsRow(_ stats: TerminalStats) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statChip("CPU", String(format: "%.0f%%", stats.cpuAbsolute))
                statChip("内存", "\(bytesText(stats.memoryBytes))/\(bytesText(stats.memoryLimitBytes))")
                statChip("磁盘", bytesText(stats.diskBytes))
                statChip("网络", networkText)
                statChip("运行", uptimeText(stats.uptime))
            }
        }
    }

    private var networkText: String {
        guard let rx = session.networkRxDelta, let tx = session.networkTxDelta else {
            return "—"
        }
        return "↑\(bytesText(tx)) ↓\(bytesText(rx))"
    }

    private func statChip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(session.lines) { line in
                        Text(line.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(12)
            }
            .background(Color(white: 0.06))
            .onChange(of: session.lines.count) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入命令", text: $command)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit(sendCommand)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Color.white.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .foregroundStyle(.white)
                .tint(.white)

            Button {
                sendCommand()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.4)
            .accessibilityLabel("发送命令")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Color(white: 0.08)
                .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.colorScheme, .dark)
    }

    private var canSend: Bool {
        session.isReady
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text(HTMLText.attributed(message))
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .tint(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("重试") {
                    Task { await connect() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Connection

    private func connect() async {
        guard !isConnecting else { return }

        isConnecting = true
        defer { isConnecting = false }

        errorMessage = nil

        do {
            let connection = try await model.loadTerminalConnection(serverID: instanceID)
            guard let url = connection.socketURL else {
                errorMessage = "终端地址无效，请稍后重试。"
                return
            }
            session.connect(token: connection.token, url: url)
        } catch let error as APIError {
            guard !Task.isCancelled else { return }

            if case .forbidden(let message) = error, message.contains("任务队列") {
                onRequireTasks()
                return
            }
            errorMessage = error.message
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func sendCommand() {
        guard session.isReady else { return }
        session.sendCommand(command)
        command = ""
    }

    // MARK: - Presentation

    private var statusText: String {
        switch session.status {
        case "running":
            return "运行中"
        case "starting":
            return "启动中"
        case "stopping":
            return "停止中"
        case "offline":
            return "离线"
        default:
            return session.status.isEmpty ? "未知" : session.status
        }
    }

    private var statusColor: Color {
        switch session.status {
        case "running":
            return .green
        case "starting", "stopping":
            return .orange
        case "offline":
            return .gray
        default:
            return .gray
        }
    }

    private func bytesText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func uptimeText(_ seconds: Double) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 {
            return "\(days) 天 \(hours) 小时"
        }
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        }
        return "\(minutes) 分钟"
    }
}
