//
//  WeChatVerificationSheet.swift
//  simpfun
//

import SwiftUI

struct WeChatVerificationSheet: View {
    let message: String

    @Environment(\.dismiss) private var dismiss

    private let steps = [
        "在微信中打开「简幻欢」小程序并登录。",
        "完成小程序内的网络环境验证。",
        "返回本应用后重新登录或下拉刷新。"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    stepList
                    serverMessage
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("身份验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("需要微信小程序验证")
                .font(.title2.bold())

            Text("当前网络环境尚未通过验证，请按以下步骤操作后重试。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.footnote.bold())
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    Text(step)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var serverMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("服务器提示")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
