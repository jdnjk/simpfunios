//
//  InstanceDetailView.swift
//  simpfun
//

import SwiftUI

struct InstanceDetailView: View {
    let instance: Instance

    @Environment(AppModel.self) private var model
    @State private var detail: InstanceDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFeature: InstanceFeature?
    @State private var hasAutoOpenedTasks = false
    @State private var isShowingShortageInfo = false
    @State private var isDrawerOpen = false
    @State private var pendingPowerAction: InstancePowerAction?
    @State private var isPerformingPower = false
    @State private var powerErrorMessage: String?
    /// 指令发出后、服务端状态真正变化前，用来展示「启动中 / 停止中」等过渡状态。
    @State private var optimisticStatus: String?
    @State private var powerFeedbackTrigger = 0
    @State private var powerFeedbackIsError = false

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                if let detail {
                    featureContent(detail)
                } else if isLoading {
                    ProgressView("正在加载实例信息…")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("无法加载实例信息", systemImage: "exclamationmark.triangle")
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

            if isDrawerOpen, let detail {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        closeDrawer()
                    }
                    .zIndex(1)

                InstanceDrawer(
                    detail: detail,
                    selectedFeature: selectedFeature,
                    onSelect: { feature in
                        selectedFeature = feature
                        closeDrawer()
                    },
                    onClose: closeDrawer
                )
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 18, x: 6, y: 0)
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if detail != nil {
                    powerMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if detail != nil {
                    Button {
                        toggleDrawer()
                    } label: {
                        Label("功能", systemImage: "sidebar.left")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingShortageInfo) {
            ShortageInfoSheet()
        }
        .confirmationDialog(
            pendingPowerAction?.title ?? "",
            isPresented: Binding(
                get: { pendingPowerAction != nil },
                set: { isPresented in
                    if !isPresented { pendingPowerAction = nil }
                }
            ),
            presenting: pendingPowerAction
        ) { action in
            Button(action.title, role: action.isDestructive ? .destructive : nil) {
                Task { await performPower(action) }
            }
            Button("取消", role: .cancel) {}
        } message: { action in
            Text(powerConfirmationMessage(for: action))
        }
        .sensoryFeedback(powerFeedbackIsError ? .error : .success, trigger: powerFeedbackTrigger)
        .task {
            await load()
        }
    }

    private func toggleDrawer() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isDrawerOpen.toggle()
        }
    }

    private func closeDrawer() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isDrawerOpen = false
        }
    }

    private var navigationTitle: String {
        if let selectedFeature {
            return selectedFeature.title
        }
        return detail?.displayName ?? instance.displayName
    }

    @ViewBuilder
    private func featureContent(_ detail: InstanceDetail) -> some View {
        if let feature = selectedFeature {
            switch feature {
            case .terminal:
                InstanceTerminalFeatureView(
                    instanceID: instance.id,
                    onRequireTasks: {
                        selectedFeature = .tasks
                    }
                )
            case .files:
                InstanceFilesFeatureView(
                    serverID: instance.id,
                    onRequireTasks: {
                        selectedFeature = .tasks
                    }
                )
            case .reinstall:
                placeholder(.reinstall)
            case .backup:
                InstanceBackupFeatureView()
            case .management:
                placeholder(.management)
            case .statistics:
                placeholder(.statistics)
            case .tasks:
                InstanceTasksFeatureView(serverID: instance.id)
            }
        } else {
            overviewContent(detail)
        }
    }

    private func placeholder(_ feature: InstanceFeature) -> some View {
        InstanceFeaturePlaceholderContent(
            title: feature.title,
            systemImage: feature.systemImage
        )
    }

    // MARK: - Content

    private func overviewContent(_ detail: InstanceDetail) -> some View {
        List {
            Section {
                header(detail)
            }

            if detail.isSuspended || detail.shortage {
                Section {
                    if detail.isSuspended {
                        Label("实例已暂停", systemImage: "pause.circle.fill")
                            .foregroundStyle(.red)
                    }
                    if detail.shortage {
                        Button {
                            isShowingShortageInfo = true
                        } label: {
                            HStack(spacing: 12) {
                                Label("所在区域资源不足", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)

                                Spacer(minLength: 8)

                                Text("详情")
                                    .font(.footnote)
                                    .foregroundStyle(.tint)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            powerSection(detail)

            featureSection

            Section("配置") {
                LabeledContent("实例 ID") {
                    value(Text(String(detail.id)).monospacedDigit())
                }

                LabeledContent("状态") {
                    value(Text(statusText(currentStatus)))
                }

                if !detail.areaGrade.isEmpty {
                    LabeledContent("区域等级") {
                        value(Text(detail.areaGrade).monospacedDigit())
                    }
                }

                LabeledContent("CPU") {
                    value(Text(verbatim: "\(detail.cpu) 核"))
                }

                LabeledContent("内存") {
                    value(Text(verbatim: "\(detail.ram) GB"))
                }

                LabeledContent("存储") {
                    value(Text(verbatim: "\(detail.disk) GB"))
                }

                LabeledContent("积分") {
                    value(Text(verbatim: "\(detail.point)").monospacedDigit())
                }
            }

            addressSection(detail)

            if let utilization = detail.utilization {
                utilizationSection(utilization, detail: detail)
            }

            resourcesSection(detail)

            if let info = detail.gameInfo {
                imageSection(info)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await load(force: true)
        }
    }

    private func header(_ detail: InstanceDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.displayName)
                    .font(.title3.bold())

                Spacer(minLength: 12)

                statusBadge(currentStatus)
            }

            if detail.isPro || detail.devMode {
                HStack(spacing: 8) {
                    if detail.isPro {
                        badge("Pro", tint: .orange)
                    }
                    if detail.devMode {
                        badge("开发模式", tint: .purple)
                    }
                }
            }

            if let info = detail.gameInfo {
                Text(verbatim: "\(info.gameName) · \(info.kindName) · \(info.versionName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 电源控制

    @ViewBuilder
    private func powerSection(_ detail: InstanceDetail) -> some View {
        let status = currentStatus.lowercased()
        let actions = availablePowerActions(for: status)

        Section {
            if detail.isSuspended {
                Label("实例已暂停，无法进行电源操作", systemImage: "pause.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isPowerBusy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(powerProgressText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
            } else if actions.isEmpty {
                Text("当前状态不支持电源操作，请稍后刷新。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(actions) { action in
                        powerButton(action, isPrimary: actions.count == 1)
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                if isKillable(status) {
                    Button(role: .destructive) {
                        requestPower(.kill)
                    } label: {
                        Label("强制停止", systemImage: InstancePowerAction.kill.systemImage)
                    }
                }
            }

            if !detail.isSuspended, let powerErrorMessage {
                Label(powerErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("电源")
        } footer: {
            Text("停止会先保存数据再关闭容器，在线玩家将被断开连接；强制停止会立即结束进程，可能造成存档丢失。")
        }
    }

    @ViewBuilder
    private func powerButton(_ action: InstancePowerAction, isPrimary: Bool) -> some View {
        let label = Label(action.title, systemImage: action.systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

        if isPrimary {
            Button {
                requestPower(action)
            } label: {
                label
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(powerTint(for: action))
        } else {
            Button {
                requestPower(action)
            } label: {
                label
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(powerTint(for: action))
        }
    }

    @ViewBuilder
    private var powerMenu: some View {
        let status = currentStatus.lowercased()

        Menu {
            Button {
                requestPower(.start)
            } label: {
                Label("启动", systemImage: InstancePowerAction.start.systemImage)
            }
            .disabled(isPowerBusy || !availablePowerActions(for: status).contains(.start))

            Button {
                requestPower(.restart)
            } label: {
                Label("重启", systemImage: InstancePowerAction.restart.systemImage)
            }
            .disabled(isPowerBusy || !availablePowerActions(for: status).contains(.restart))

            Divider()

            Button(role: .destructive) {
                requestPower(.stop)
            } label: {
                Label("停止", systemImage: InstancePowerAction.stop.systemImage)
            }
            .disabled(isPowerBusy || !availablePowerActions(for: status).contains(.stop))

            Button(role: .destructive) {
                requestPower(.kill)
            } label: {
                Label("强制停止", systemImage: InstancePowerAction.kill.systemImage)
            }
            .disabled(isPowerBusy || !isKillable(status))
        } label: {
            Label("电源", systemImage: "power")
        }
        .disabled(detail?.isSuspended ?? true)
    }

    private var currentStatus: String {
        optimisticStatus ?? detail?.status ?? ""
    }

    private var isPowerBusy: Bool {
        isPerformingPower || optimisticStatus != nil
    }

    private var powerProgressText: String {
        guard let optimisticStatus else { return "正在发送指令…" }
        return statusText(optimisticStatus) + "…"
    }

    private func availablePowerActions(for status: String) -> [InstancePowerAction] {
        switch status {
        case "running", "online":
            return [.restart, .stop]
        case "starting", "stopping", "restarting":
            return []
        case "offline", "stopped", "":
            return [.start]
        default:
            // 未知状态时把启动/重启/停止都放出来，是否允许交由服务端判断。
            return [.start, .restart, .stop]
        }
    }

    private func isKillable(_ status: String) -> Bool {
        switch status {
        case "running", "online", "starting", "stopping", "restarting":
            return true
        default:
            return false
        }
    }

    private func powerTint(for action: InstancePowerAction) -> Color {
        switch action {
        case .start:
            return .green
        case .stop, .kill:
            return .red
        case .restart:
            return .accentColor
        }
    }

    private func powerConfirmationMessage(for action: InstancePowerAction) -> String {
        switch action {
        case .stop:
            return "服务器会先保存数据，再关闭容器，在线玩家将被断开连接。"
        case .kill:
            return "立即结束服务器进程，未保存的进度可能丢失。仅在无法正常停止时使用。"
        case .start, .restart:
            return ""
        }
    }

    /// 启动与重启可以直接执行；停止与强制停止会打断玩家，先弹系统确认框。
    private func requestPower(_ action: InstancePowerAction) {
        guard !isPowerBusy else { return }
        powerErrorMessage = nil

        if action.requiresConfirmation {
            pendingPowerAction = action
        } else {
            Task { await performPower(action) }
        }
    }

    private func performPower(_ action: InstancePowerAction) async {
        guard let serverID = detail?.id, !isPerformingPower else { return }

        isPerformingPower = true
        powerErrorMessage = nil

        let statusBeforeAction = currentStatus
        optimisticStatus = action.transitionalStatus

        defer { isPerformingPower = false }

        do {
            try await model.powerInstance(serverID: serverID, action: action)
            powerFeedbackIsError = false
            powerFeedbackTrigger += 1
        } catch let error as APIError {
            optimisticStatus = nil
            powerFeedbackIsError = true
            powerFeedbackTrigger += 1
            handlePowerError(error)
            return
        } catch {
            optimisticStatus = nil
            powerErrorMessage = error.localizedDescription
            return
        }

        // 容器真正变更状态需要几秒，轮询几次把界面拉回服务端的真实状态。
        for _ in 0..<3 {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            await load(force: true)
            if detail?.status != statusBeforeAction { break }
        }

        optimisticStatus = nil
    }

    private func handlePowerError(_ error: APIError) {
        switch error {
        case .forbidden(let message) where message.contains("任务队列"):
            // 实例正在执行其它任务，直接带到任务页处理，避免用户卡在原地。
            selectedFeature = .tasks
        case .ipNotVerified, .verificationRequired, .notSignedIn, .invalidToken:
            // AppModel 已经弹出小程序验证或登录失效提示，这里不再重复展示。
            break
        default:
            powerErrorMessage = error.message
        }
    }

    private var featureSection: some View {
        Section("功能") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 12)], spacing: 16) {
                ForEach(InstanceFeature.allCases) { feature in
                    Button {
                        selectedFeature = feature
                    } label: {
                        featureTile(feature.title, systemImage: feature.systemImage)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
        }
    }

    private func featureTile(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 46, height: 46)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func addressSection(_ detail: InstanceDetail) -> some View {
        if let defaultAllocation = detail.defaultAllocation {
            Section("地址") {
                LabeledContent("默认地址") {
                    endpointText(defaultAllocation.endpoint)
                }

                ForEach(detail.allocations.filter { $0.endpoint != defaultAllocation.endpoint }) { allocation in
                    LabeledContent("其他地址") {
                        endpointText(allocation.endpoint)
                    }
                }
            }
        } else if !detail.allocations.isEmpty {
            Section("地址") {
                ForEach(detail.allocations) { allocation in
                    LabeledContent(allocation.isDefault ? "默认地址" : "其他地址") {
                        endpointText(allocation.endpoint)
                    }
                }
            }
        }
    }

    private func utilizationSection(
        _ utilization: InstanceUtilization,
        detail: InstanceDetail
    ) -> some View {
        Section("运行状态") {
            LabeledContent("CPU") {
                value(Text(verbatim: String(format: "%.1f%%", utilization.cpuAbsolute)).monospacedDigit())
            }

            LabeledContent("内存") {
                value(Text(verbatim: "\(bytesText(utilization.memoryBytes)) / \(detail.ram) GB"))
            }

            LabeledContent("磁盘") {
                value(Text(verbatim: "\(bytesText(utilization.diskBytes)) / \(detail.disk) GB"))
            }

            LabeledContent("网络") {
                value(Text(verbatim: "↑ \(bytesText(utilization.networkTxBytes)) · ↓ \(bytesText(utilization.networkRxBytes))"))
            }

            LabeledContent("运行时长") {
                value(Text(verbatim: uptimeText(utilization.uptime)))
            }

            if let checkTime = utilization.diskLastCheckTime {
                LabeledContent("磁盘检查") {
                    value(Text(checkTime, format: .dateTime.year().month().day().hour().minute()))
                }
            }
        }
    }

    @ViewBuilder
    private func resourcesSection(_ detail: InstanceDetail) -> some View {
        Section("资源") {
            if let diamond = detail.diamond {
                LabeledContent("钻石余额") {
                    value(Text(verbatim: "\(diamond.left)").monospacedDigit())
                }
            }

            if let traffic = detail.traffic {
                LabeledContent("剩余流量") {
                    value(Text(verbatim: "剩余 \(bytesText(traffic.remainBytes)) · 套餐 \(traffic.plan) GB"))
                }

                LabeledContent("流量重置") {
                    value(Text(traffic.autoReset ? "自动" : "手动"))
                }
            }

            if let createTime = detail.createTime {
                LabeledContent("创建时间") {
                    value(Text(createTime, format: .dateTime.year().month().day().hour().minute()))
                }
            }

            if let lastPaidTime = detail.lastPaidTime {
                LabeledContent("最后付费") {
                    value(Text(lastPaidTime, format: .dateTime.year().month().day().hour().minute()))
                }
            }
        }
    }

    @ViewBuilder
    private func imageSection(_ info: InstanceGameInfo) -> some View {
        Section("镜像") {
            LabeledContent("游戏") {
                value(Text(info.gameName))
            }

            LabeledContent("服务端") {
                value(Text(info.kindName))
            }

            LabeledContent("版本") {
                value(Text(info.versionName))
            }

            if info.custom {
                LabeledContent("来源") {
                    value(Text("第三方镜像"))
                }
            }
        }

        if let description = info.description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section("镜像说明") {
                Text(MarkdownText.attributed(description))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .tint(Color.accentColor)
                    .textSelection(.enabled)
            }
        }

        if let url = info.linkURL {
            Section {
                Link(destination: url) {
                    Label("查看镜像详情", systemImage: "safari")
                }
            }
        }
    }

    // MARK: - Presentation helpers

    private func value<Content: View>(_ content: Content) -> some View {
        content.foregroundStyle(.secondary)
    }

    private func endpointText(_ endpoint: String) -> some View {
        Text(endpoint)
            .font(.callout.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func statusBadge(_ status: String) -> some View {
        badge(statusText(status), tint: statusColor(status))
    }

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func statusText(_ status: String) -> String {
        switch status.lowercased() {
        case "running", "online":
            return "运行中"
        case "offline", "stopped":
            return "离线"
        case "starting":
            return "启动中"
        case "restarting":
            return "重启中"
        case "stopping":
            return "停止中"
        case "suspended":
            return "已暂停"
        default:
            return status.isEmpty ? "未知" : status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "running", "online":
            return .green
        case "offline", "stopped":
            return .gray
        case "starting", "stopping", "restarting":
            return .orange
        case "suspended":
            return .red
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

    // MARK: - Loading

    private func load(force: Bool = false) async {
        guard (force || detail == nil) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await model.loadInstanceDetail(serverID: instance.id)
            detail = loaded
            errorMessage = nil

            if loaded.haveTask && !hasAutoOpenedTasks {
                hasAutoOpenedTasks = true
                selectedFeature = .tasks
            }
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShortageInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("当前节点资源紧张，关闭服务器后资源会被释放，可能被他人占用，导致实例无法再次启动。")
                    Text("如遇到无法启动的问题，可通过变配迁移到其它空闲节点。")
                    Text("我们严格限制节点负载，拒绝超开，以保障每位用户的性能体验。")
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("节点资源提示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
