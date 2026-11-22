//
//  TranslationSheet.swift
//  simpfun
//

import SwiftUI

/// 翻译模式：把文件逐行送去 Azure 翻译，按原行号列出来，点一条即可跳到对应行。
///
/// 密钥目前存在 UserDefaults（`@AppStorage`），等正式 token 到位后
/// 可以换成 Keychain，或改为登录态下发的临时 token。
struct TranslationSheet: View {
    let text: String
    var onJump: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("azureTranslatorKey") private var key = ""
    @AppStorage("azureTranslatorRegion") private var region = ""
    @AppStorage("azureTranslatorEndpoint") private var endpoint = "https://api.cognitive.microsofttranslator.com"

    @State private var isConfiguring = false
    @State private var isTranslating = false
    @State private var rows: [Row] = []
    @State private var errorMessage: String?
    @State private var progress = ""

    struct Row: Identifiable {
        let id = UUID()
        let line: Int
        let source: String
        let translated: String
    }

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty {
                    emptyView
                } else {
                    resultList
                }
            }
            .navigationTitle("翻译模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("翻译设置") { isConfiguring = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $isConfiguring) {
                TranslationSettingsSheet()
            }
            .overlay {
                if isTranslating {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(progress.isEmpty ? "正在翻译…" : progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("翻译模式", systemImage: "character.bubble")
        } description: {
            if let errorMessage {
                Text(errorMessage)
            } else if key.isEmpty {
                Text("使用 Azure 翻译把文件内容逐行译成中文。先填入订阅密钥与区域，之后每次打开都能直接翻译。")
            } else {
                Text("已配置 Azure 翻译，点击下方按钮开始翻译当前文件。")
            }
        } actions: {
            Button {
                Task { await translate() }
            } label: {
                Label("开始翻译", systemImage: "character.bubble.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTranslating)

            Button("翻译设置…") { isConfiguring = true }
        }
    }

    private var resultList: some View {
        List {
            Section {
                ForEach(rows) { row in
                    Button {
                        onJump(row.line)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("第 \(row.line) 行")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(row.source)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(row.translated)
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("共 \(rows.count) 行")
            } footer: {
                Text("点击任意一条可跳回编辑器对应行。")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func translate() async {
        guard !isTranslating else { return }
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isConfiguring = true
            return
        }

        let entries = Self.entries(in: text)
        guard !entries.isEmpty else {
            errorMessage = "文件没有可翻译的文本。"
            return
        }

        isTranslating = true
        errorMessage = nil
        defer {
            isTranslating = false
            progress = ""
        }

        var collected: [Row] = []
        let configuration = AzureTranslator.Configuration(endpoint: endpoint, region: region, key: key)

        do {
            let batches = Self.batches(entries)
            for (index, batch) in batches.enumerated() {
                progress = "正在翻译 \(index + 1)/\(batches.count)…"
                let outputs = try await AzureTranslator.translate(
                    batch.map(\.source),
                    configuration: configuration
                )
                for (entry, output) in zip(batch, outputs) {
                    collected.append(Row(line: entry.line, source: entry.source, translated: output))
                }
            }
            rows = collected
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 文本切分

    private static func entries(in text: String) -> [(line: Int, source: String)] {
        text.components(separatedBy: "\n").enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return (index + 1, trimmed)
        }
    }

    private static func batches(_ entries: [(line: Int, source: String)]) -> [[(line: Int, source: String)]] {
        var result: [[(line: Int, source: String)]] = []
        var current: [(line: Int, source: String)] = []
        var characters = 0

        for entry in entries {
            let overflow = characters + entry.source.count > AzureTranslator.maximumCharactersPerRequest
            let tooMany = current.count >= AzureTranslator.maximumLinesPerRequest
            if !current.isEmpty, overflow || tooMany {
                result.append(current)
                current = []
                characters = 0
            }
            current.append(entry)
            characters += entry.source.count
        }

        if !current.isEmpty { result.append(current) }
        return result
    }
}

/// Azure 翻译的连接设置。密钥先存在本地，仅用于调用翻译接口。
private struct TranslationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("azureTranslatorKey") private var key = ""
    @AppStorage("azureTranslatorRegion") private var region = ""
    @AppStorage("azureTranslatorEndpoint") private var endpoint = "https://api.cognitive.microsofttranslator.com"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("订阅密钥 (Ocp-Apim-Subscription-Key)", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("区域，例如 eastasia", text: $region)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("服务地址", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                } header: {
                    Text("Azure AI Translator")
                } footer: {
                    Text("密钥保存在本机偏好设置中，仅用于直连微软翻译接口。区域留空时按全局资源配置。")
                }
            }
            .navigationTitle("翻译设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
