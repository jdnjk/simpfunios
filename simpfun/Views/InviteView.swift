//
//  InviteView.swift
//  simpfun
//

import SwiftUI
import UIKit

struct InviteView: View {
    @Environment(AppModel.self) private var model

    @State private var inviteInfo: InviteInfo?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var copiedTarget: CopyTarget?
    @State private var copyTask: Task<Void, Never>?

    private enum CopyTarget {
        case code
        case link
    }

    var body: some View {
        Group {
            if let inviteInfo {
                content(inviteInfo)
            } else if isLoading {
                ProgressView("正在加载邀请信息…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("无法加载邀请信息", systemImage: "exclamationmark.triangle")
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
        .navigationTitle("邀请好友")
        .task { await load() }
    }

    private func content(_ inviteInfo: InviteInfo) -> some View {
        List {
            Section {
                inviteCodeCard(inviteInfo)
                    .padding(.vertical, 4)
            }

            Section("邀请数据") {
                LabeledContent("注册人数") {
                    Text(inviteInfo.registerTimes, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                LabeledContent("已认证人数") {
                    Text(inviteInfo.registerVerifyTimes, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                LabeledContent("邀请获得积分") {
                    Text(inviteInfo.registerTotalIncome, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Pro 用户邀请积分") {
                    Text(inviteInfo.registerTotalIncomeFromPro, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section("推荐规则") {
                Text(rulesText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("激励计划") {
                Text("对于有视频/文稿创作经验的用户可以申请积分扶持，提供日常开服补助以及一定的创作指导。\n您可以前往 微信小程序 → 用户管理 → 激励计划 申请。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load(force: true) }
    }

    private func inviteCodeCard(_ inviteInfo: InviteInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("我的邀请码")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center) {
                    Button {
                        copy(String(inviteInfo.inviteCode), as: .code)
                    } label: {
                        Text(String(inviteInfo.inviteCode))
                            .font(.system(.title, design: .monospaced).weight(.bold))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("邀请码 \(inviteInfo.inviteCode)，点按复制")

                    Spacer(minLength: 12)

                    Button {
                        copy(String(inviteInfo.inviteCode), as: .code)
                    } label: {
                        Label(
                            copiedTarget == .code ? "已复制" : "复制",
                            systemImage: copiedTarget == .code ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let inviteLink = inviteInfo.inviteLink {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("邀请链接")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        copy(inviteLink.absoluteString, as: .link)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(inviteLink.absoluteString)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.tint)

                            Spacer(minLength: 8)

                            Image(systemName: copiedTarget == .link ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("邀请链接，点按复制")
                }
            }

            if let inviteLink = inviteInfo.inviteLink {
                ShareLink(item: inviteLink) {
                    Label("分享邀请链接", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var rulesText: String {
        """
        推荐好友使用简幻欢可以获得更多积分！
        让好友成为自动造分🐔：）
        好友注册并认证 = 好友获得 25 额外积分，您获得 25 积分 + 1 钻石
        好友每日签到 = 您获得 1 积分
        变更为 Pro 的好友充值，您将获得充值金额 ×4 的积分，且会单独列出
        每日获得积分无上限哦～

        让好友在注册页面输入上方邀请码，才可以获得积分哦～

        限制：
        1. 您不得利用系统漏洞或使用小号获得不正当收益
        2. 您不得将推荐码以任何形式（群名片、发言、私聊等）在简幻欢官方交流群内发送
        3. 您不得以非正当方式（刷屏等）方式进行推荐
        违规将移出交流群，扣除推荐积分，严重者封号处理。
        """
    }

    private func copy(_ value: String, as target: CopyTarget) {
        UIPasteboard.general.string = value
        copiedTarget = target

        copyTask?.cancel()
        copyTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copiedTarget = nil
        }
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            inviteInfo = try await model.loadInviteInfo()
            errorMessage = nil
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        InviteView()
            .environment(AppModel())
    }
}
