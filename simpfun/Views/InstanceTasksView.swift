//
//  InstanceTasksView.swift
//  simpfun
//

import SwiftUI

struct InstanceTasksView: View {
    let serverID: Int

    @Environment(AppModel.self) private var model
    @State private var tasks: InstanceTasks?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isPerformingAction = false
    @State private var alert: TaskAlert?

    var body: some View {
        Group {
            if let tasks {
                content(tasks)
            } else if isLoading {
                ProgressView("正在加载任务…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("无法加载任务", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") {
                        Task { await load(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await load()
        }
        .alert(
            alert?.title ?? "",
            isPresented: Binding(
                get: { alert != nil },
                set: { isPresented in
                    if !isPresented { alert = nil }
                }
            ),
            presenting: alert
        ) { alert in
            switch alert {
            case .promote(let taskID):
                Button("取消", role: .cancel) {}
                Button("确认加速") {
                    Task { await promote(taskID) }
                }
            case .cancel(let taskID):
                Button("再想想", role: .cancel) {}
                Button("取消任务", role: .destructive) {
                    Task { await cancel(taskID) }
                }
            case .error:
                Button("好", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private func content(_ tasks: InstanceTasks) -> some View {
        List {
            Section("队列状态") {
                LabeledContent("队列类型") {
                    value(Text(tasks.isPro ? "Pro" : "普通"))
                }

                LabeledContent("正在执行") {
                    value(Text(verbatim: "\(tasks.running)").monospacedDigit())
                }

                LabeledContent("等待中") {
                    value(Text(verbatim: "\(tasks.waiting)").monospacedDigit())
                }

                LabeledContent("Pro 队列") {
                    value(Text(verbatim: "运行 \(tasks.runningPro) · 等待 \(tasks.waitingPro)").monospacedDigit())
                }

                if tasks.numFirstWaiting > 0 {
                    LabeledContent("首位等待任务") {
                        value(Text(verbatim: "#\(tasks.numFirstWaiting)").monospacedDigit())
                    }
                }

                if tasks.numFirstWaitingPro > 0 {
                    LabeledContent("Pro 首位等待") {
                        value(Text(verbatim: "#\(tasks.numFirstWaitingPro)").monospacedDigit())
                    }
                }
            }

            actionSection(tasks)

            Section("任务列表") {
                if tasks.list.isEmpty {
                    Text("暂无任务")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks.list) { task in
                        taskRow(task)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await load(force: true)
        }
    }

    @ViewBuilder
    private func actionSection(_ tasks: InstanceTasks) -> some View {
        if let firstWaiting = tasks.firstWaitingTask {
            Section {
                if !tasks.isPro {
                    Button {
                        alert = .promote(firstWaiting.id)
                    } label: {
                        Label("加速至 Pro 队列（100 积分）", systemImage: "bolt.fill")
                    }
                    .disabled(isPerformingAction)
                }

                Button(role: .destructive) {
                    alert = .cancel(firstWaiting.id)
                } label: {
                    Label("取消等待任务", systemImage: "xmark.circle")
                }
                .disabled(isPerformingAction)
            } footer: {
                if tasks.isPro {
                    Text("当前任务已在 Pro 队列中。")
                } else {
                    Text("加速会将当前实例所有等待中的任务切换到 Pro 队列。")
                }
            }
        }
    }

    private func taskRow(_ task: InstanceTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: taskSystemImage(task.status))
                .font(.title3)
                .foregroundStyle(taskColor(task.status))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.comment)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    Text(verbatim: "#\(task.id)")
                    if let createTime = task.createTime {
                        Text(createTime, format: .dateTime.month().day().hour().minute())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Spacer(minLength: 8)

            Text(taskStatusText(task.status))
                .font(.caption.weight(.semibold))
                .foregroundStyle(taskColor(task.status))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func promote(_ taskID: Int) async {
        guard !isPerformingAction else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await model.promoteInstanceTasks(serverID: serverID, taskID: taskID)
            await load(force: true)
            await model.refreshUserInfo(force: true)
        } catch let error as APIError {
            alert = .error(error.message)
        } catch {
            alert = .error(error.localizedDescription)
        }
    }

    private func cancel(_ taskID: Int) async {
        guard !isPerformingAction else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await model.cancelInstanceTask(serverID: serverID, taskID: taskID)
            await load(force: true)
        } catch let error as APIError {
            alert = .error(error.message)
        } catch {
            alert = .error(error.localizedDescription)
        }
    }

    private func load(force: Bool = false) async {
        guard (force || tasks == nil) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            tasks = try await model.loadInstanceTasks(serverID: serverID)
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Presentation helpers

    private func value<Content: View>(_ content: Content) -> some View {
        content.foregroundStyle(.secondary)
    }

    private func taskStatusText(_ status: Int) -> String {
        switch status {
        case -2:
            return "执行中"
        case -1:
            return "等待执行"
        case 0:
            return "已完成"
        case 1:
            return "任务出错"
        default:
            return "状态 \(status)"
        }
    }

    private func taskSystemImage(_ status: Int) -> String {
        switch status {
        case -2:
            return "arrow.triangle.2.circlepath"
        case -1:
            return "clock.fill"
        case 0:
            return "checkmark.circle.fill"
        case 1:
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle"
        }
    }

    private func taskColor(_ status: Int) -> Color {
        switch status {
        case -2:
            return .blue
        case -1:
            return .orange
        case 0:
            return .green
        case 1:
            return .red
        default:
            return .gray
        }
    }
}

private enum TaskAlert: Identifiable {
    case promote(Int)
    case cancel(Int)
    case error(String)

    var id: String {
        switch self {
        case .promote(let taskID):
            return "promote-\(taskID)"
        case .cancel(let taskID):
            return "cancel-\(taskID)"
        case .error(let message):
            return "error-\(message)"
        }
    }

    var title: String {
        switch self {
        case .promote:
            return "加速 (变更至Pro队列)"
        case .cancel:
            return "取消任务？"
        case .error:
            return "操作失败"
        }
    }

    var message: String {
        switch self {
        case .promote:
            return """
            在Pro队列处于空闲状态时，非Pro用户可以花费100积分/次将当前实例所有等待执行状态的任务切换至Pro队列。

            Pro队列优先级更高，处理速度更快。

            您确认要消耗100积分进行加速吗？
            """
        case .cancel(let taskID):
            return "将取消第一个等待中的任务（#\(taskID)）。"
        case .error(let message):
            return message
        }
    }
}
