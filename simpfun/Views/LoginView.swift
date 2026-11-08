//
//  LoginView.swift
//  simpfun
//

import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 32) {
                header

                VStack(spacing: 20) {
                    credentialFields(viewModel: $viewModel)
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
