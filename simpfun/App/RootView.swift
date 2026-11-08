//
//  RootView.swift
//  simpfun
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ZStack {
            switch model.authState {
            case .restoring:
                LaunchView()
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.authState)
        .task {
            await model.restoreSession()
        }
        .sheet(item: $model.activeSheet, onDismiss: { model.handleSheetDismissed() }) { sheet in
            switch sheet {
            case .announcement(let announcement):
                AnnouncementSheet(announcement: announcement)
            case .wechatVerification(let message):
                WeChatVerificationSheet(message: message)
            }
        }
        .alert(
            model.notice?.title ?? "",
            isPresented: Binding(
                get: { model.notice != nil },
                set: { isPresented in
                    if !isPresented { model.notice = nil }
                }
            ),
            presenting: model.notice
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 24) {
            BrandIcon()
            ProgressView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在启动")
    }
}

#Preview {
    RootView()
        .environment(AppModel())
}
