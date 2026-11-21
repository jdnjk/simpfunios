//
//  ConfirmationView.swift
//  simpfun
//

import SwiftUI

struct ConfirmationView: View {
    let mirror: MirrorType
    let version: GameVersion
    let item: ShopItem
    let onFinished: () -> Void

    @Environment(AppModel.self) private var model

    @State private var confirmation: InstanceConfirmation?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadErrorMessage: String?
    @State private var isCreating = false
    @State private var createErrorMessage: String?

    var body: some View {
        Group {
            if let confirmation {
                content(confirmation)
            } else if isLoading {
                ProgressView("正在准备订单…")
            } else if let loadErrorMessage {
                ContentUnavailableView {
                    Label("无法加载确认信息", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadErrorMessage)
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
        .navigationTitle("确认实例")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if confirmation != nil {
                createBar
            }
        }
        .alert(
            "创建失败",
            isPresented: Binding(
                get: { createErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { createErrorMessage = nil }
                }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(createErrorMessage ?? "")
        }
        .task {
            await load()
        }
    }

    private func content(_ confirmation: InstanceConfirmation) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(confirmation.imageName)
                        .font(.headline)

                    Text(verbatim: "\(confirmation.gameName) · \(confirmation.versionName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("配置") {
                LabeledContent("规格") {
                    Text(confirmation.grade)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                LabeledContent("CPU") {
                    Text(verbatim: "\(confirmation.cpu) 核")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("内存") {
                    Text(verbatim: "\(confirmation.ram) GB")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("存储") {
                    Text(verbatim: "\(confirmation.disk) GB")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("流量") {
                    Text(verbatim: "\(confirmation.traffic) GB")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("所需积分") {
                    Text(verbatim: "\(confirmation.point)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if let description = confirmation.description,
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("说明") {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var createBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                Task { await create() }
            } label: {
                Group {
                    if isCreating {
                        ProgressView()
                    } else {
                        Text("创建实例")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 22)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCreating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            confirmation = try await model.loadConfirmation(
                versionID: version.id,
                itemID: item.id,
                custom: mirror.isCustom
            )
            loadErrorMessage = nil
            hasLoaded = true
        } catch let error as APIError {
            loadErrorMessage = error.message
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private func create() async {
        guard !isCreating else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            try await model.createInstance(
                versionID: version.id,
                itemID: item.id,
                custom: mirror.isCustom
            )
            onFinished()

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                await model.refreshAll()
            }
        } catch let error as APIError {
            createErrorMessage = error.message
        } catch {
            createErrorMessage = error.localizedDescription
        }
    }
}
