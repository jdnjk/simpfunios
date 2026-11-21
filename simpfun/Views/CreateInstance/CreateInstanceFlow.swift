//
//  CreateInstanceFlow.swift
//  simpfun
//

import SwiftUI

enum CreateInstanceStep: Hashable {
    case game(MirrorType)
    case kind(MirrorType, Game)
    case version(MirrorType, GameKind)
    case spec(MirrorType, GameVersion)
    case confirmation(MirrorType, GameVersion, ShopItem)
}

struct CreateInstanceFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [CreateInstanceStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            MirrorSelectionView(path: $path)
                .navigationTitle("创建实例")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: CreateInstanceStep.self) { step in
                    destination(for: step)
                }
        }
    }

    @ViewBuilder
    private func destination(for step: CreateInstanceStep) -> some View {
        switch step {
        case .game(let mirror):
            GameSelectionView(mirror: mirror)
        case .kind(let mirror, let game):
            KindSelectionView(mirror: mirror, game: game)
        case .version(let mirror, let kind):
            VersionSelectionView(mirror: mirror, kind: kind)
        case .spec(let mirror, let version):
            SpecSelectionView(mirror: mirror, version: version)
        case .confirmation(let mirror, let version, let item):
            ConfirmationView(
                mirror: mirror,
                version: version,
                item: item,
                onFinished: { dismiss() }
            )
        }
    }
}

private struct MirrorSelectionView: View {
    @Binding var path: [CreateInstanceStep]

    @State private var isShowingDisclaimer = false
    @State private var shouldContinueAfterDisclaimer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("选择镜像类型")
                    .font(.headline)
                    .padding(.top, 8)

                mirrorCard(.official) {
                    path.append(.game(.official))
                }

                mirrorCard(.thirdParty) {
                    isShowingDisclaimer = true
                }

                Text("官方镜像由简幻欢维护；第三方镜像由第三方开发者上传。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingDisclaimer, onDismiss: {
            if shouldContinueAfterDisclaimer {
                shouldContinueAfterDisclaimer = false
                path.append(.game(.thirdParty))
            }
        }) {
            ThirdPartyDisclaimerView(
                onCancel: {
                    isShowingDisclaimer = false
                },
                onAccept: {
                    shouldContinueAfterDisclaimer = true
                    isShowingDisclaimer = false
                }
            )
        }
    }

    private func mirrorCard(_ mirror: MirrorType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: mirror.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 52, height: 52)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(mirror.title)
                        .font(.headline)
                    Text(mirror.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ThirdPartyDisclaimerView: View {
    let onCancel: () -> Void
    let onAccept: () -> Void

    private let disclaimer = """
    第三方镜像由第三方开发者提供，由开发者自主上传，简幻欢不能保证第三方镜像的安全性和完整性，镜像内部问题与简幻欢无关，请联系第三方开发者。

    使用第三方镜像可能存在安全风险，包括但不限于数据泄露，恶意软件等。您应该自行采取适当应对措施。

    如果您认为第三方镜像存在侵犯您的权利或违反了相关法规的内容，请您先联系开发者，若无法解决请联系QQ:2836068358。

    将在收到通知后立即对相关内容采取适当的措施，包括但不限于删除、屏蔽或禁止访问相关内容。

    某些第三方开发者可能会向您收取授权费用、技术支持费用或其他相关费用。这些费用由第三方开发者直接收取，与简幻欢无关。
    """

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("第三方镜像风险及免责声明")
                        .font(.headline)

                    Text(disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("免责声明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAccept()
                } label: {
                    Text("我已知晓，继续")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(20)
                .background(.bar)
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    CreateInstanceFlow()
        .environment(AppModel())
}
