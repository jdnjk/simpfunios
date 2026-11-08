//
//  ProfileView.swift
//  simpfun
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingSignOutConfirmation = false
    @State private var isShowingQQBinding = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = model.user {
                    profileList(user)
                } else if model.isLoadingUser {
                    ProgressView("正在加载账户信息…")
                } else {
                    unavailable
                }
            }
            .navigationTitle("我的")
        }
        .task {
            await model.refreshUserInfo()
        }
    }

    private func profileList(_ user: UserInfo) -> some View {
        List {
            Section {
                header(user)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            }

            Section {
                LabeledContent("用户 ID") {
                    Text(String(user.id))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                qqRow(user)

                LabeledContent("注册时间") {
                    Text(user.createTime, format: .dateTime.year().month().day())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("账户")
            } footer: {
                if !user.verified && (user.qq ?? 0) == 0 {
                    Text("完成账号认证后可以绑定 QQ。")
                }
            }

            Section("资产") {
                NavigationLink {
                    PointHistoryView()
                } label: {
                    LabeledContent {
                        Text(user.point, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("积分", systemImage: "sparkles")
                    }
                }

                NavigationLink {
                    DiamondHistoryView()
                } label: {
                    LabeledContent {
                        Text(user.diamond, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("钻石", systemImage: "diamond.fill")
                    }
                }
            }

            Section("更多") {
                NavigationLink {
                    AnnouncementListView()
                } label: {
                    Label("公告", systemImage: "megaphone")
                }

                NavigationLink {
                    InviteView()
                } label: {
                    Label("邀请好友", systemImage: "person.badge.plus")
                }
            }

            Section {
                Button("退出登录", role: .destructive) {
                    isShowingSignOutConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await model.refreshUserInfo(force: true)
        }
        .confirmationDialog(
            "退出登录？",
            isPresented: $isShowingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                model.signOut()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后需要重新输入账号和密码。")
        }
        .sheet(isPresented: $isShowingQQBinding) {
            QQBindingSheet(currentQQ: user.qq)
        }
    }

    private func header(_ user: UserInfo) -> some View {
        VStack(spacing: 12) {
            Text(String(user.username.prefix(1)).uppercased())
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .frame(width: 76, height: 76)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(user.username)
                .font(.title2.bold())

            if user.verified || user.isDev || user.isPro || user.proValid {
                HStack(spacing: 8) {
                    if user.verified {
                        ProfileBadge(title: "已认证", systemImage: "checkmark.seal.fill", tint: .blue)
                    }
                    if user.isDev {
                        ProfileBadge(title: "开发者", systemImage: "hammer.fill", tint: .purple)
                    }
                    if user.isPro || user.proValid {
                        ProfileBadge(
                            title: user.proValid ? "Pro+" : "Pro",
                            systemImage: "crown.fill",
                            tint: .orange
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func qqRow(_ user: UserInfo) -> some View {
        if let qq = user.qq, qq > 0 {
            if user.verified {
                Button {
                    isShowingQQBinding = true
                } label: {
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text(String(qq))
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            Text("换绑")
                                .foregroundStyle(.tint)
                        }
                    } label: {
                        Text("QQ")
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                LabeledContent("QQ") {
                    Text(String(qq))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } else if user.verified {
            Button {
                isShowingQQBinding = true
            } label: {
                LabeledContent("QQ") {
                    Text("绑定")
                }
            }
        } else {
            LabeledContent("QQ") {
                Text("未绑定")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label("无法加载账户信息", systemImage: "exclamationmark.triangle")
        } description: {
            Text(model.userErrorMessage ?? "请检查网络后重试。")
        } actions: {
            Button("重试") {
                Task { await model.refreshUserInfo(force: true) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ProfileBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

#Preview {
    ProfileView()
        .environment(AppModel())
}
