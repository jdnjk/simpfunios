//
//  LoginView.swift
//  simpfun
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    private var usesWideLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        if usesWideLayout {
            wideLayout
        } else {
            compactLayout
        }
    }

    // MARK: - iPhone

    private var compactLayout: some View {
        let bindable = Bindable(viewModel)

        return ScrollView {
            VStack(spacing: 32) {
                header

                VStack(spacing: 20) {
                    credentialFields(viewModel: bindable)
                    loginButton
                    errorMessage
                }
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 56)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    private var header: some View {
        VStack(spacing: 16) {
            BrandIcon()

            VStack(spacing: 6) {
                Text("简幻欢")
                    .font(.largeTitle.bold())
                Text("登录你的账号以管理实例")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - iPad

    private var wideLayout: some View {
        let bindable = Bindable(viewModel)

        return HStack(spacing: 0) {
            brandHero

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("欢迎回来")
                            .font(.system(size: 34, weight: .bold))
                        Text("使用简幻欢账号登录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 20) {
                        credentialFields(viewModel: bindable)
                        loginButton
                        errorMessage
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 48)
                .frame(maxWidth: 460)
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(width: 500)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    private var brandHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            BrandIcon(size: 104)

            VStack(alignment: .leading, spacing: 10) {
                Text("简幻欢")
                    .font(.system(size: 44, weight: .bold))
                Text("登录你的账号以管理实例")
                    .font(.title3)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 14) {
                featureRow("server.rack", "实例状态一目了然")
                featureRow("sparkles", "积分与邀请尽在掌握")
                featureRow("megaphone", "重要公告及时送达")
            }
            .padding(.top, 40)

            Spacer(minLength: 0)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func featureRow(_ systemImage: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 24)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Shared

    private func credentialFields(viewModel: Bindable<LoginViewModel>) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("用户名")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("请输入用户名", text: viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
            }
            .padding(16)

            Divider()
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("密码")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("请输入密码", text: viewModel.password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submit)
            }
            .padding(16)
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var loginButton: some View {
        Button(action: submit) {
            Group {
                if viewModel.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("登录中…")
                    }
                } else if viewModel.cooldownRemaining > 0 {
                    Text("请稍候（\(viewModel.cooldownRemaining)s）")
                        .monospacedDigit()
                } else {
                    Text("登录")
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.isLoginEnabled)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let message = viewModel.errorMessage {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message)
            }
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    private func submit() {
        guard viewModel.isLoginEnabled else { return }
        focusedField = nil
        Task { await viewModel.submit(using: model) }
    }
}

#Preview {
    LoginView()
        .environment(AppModel())
}
