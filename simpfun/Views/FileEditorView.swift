//
//  FileEditorView.swift
//  simpfun
//

import SwiftUI
import UIKit

/// 远程文本文件编辑器。
///
/// 结构：导航栏下是状态条（文件名 / 行列 / 编码 / 换行符），
/// 需要时展开查找替换条，其余空间给代码编辑区。
struct FileEditorView: View {
    let serverID: Int
    let initialPath: String
    let initialName: String
    var onRequireTasks: () -> Void = {}

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var controller = EditorController()
    @State private var path: String
    @State private var fileName: String
    @State private var text = ""
    @State private var savedText = ""
    @State private var language: SyntaxLanguage
    @State private var encoding: TextEncoding = .utf8
    @State private var lineEnding: LineEnding = .lf
    @State private var isLineWrappingEnabled = true

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var isSaving = false
    @State private var selection = NSRange(location: 0, length: 0)

    @State private var isFindVisible = false
    @State private var findQuery = ""
    @State private var replaceQuery = ""
    @State private var findOptions = FindOptions()
    @State private var matches: [NSRange] = []
    @State private var currentMatch = 0

    @State private var isShowingGotoLine = false
    @State private var gotoLineInput = ""
    @State private var isShowingSaveAs = false
    @State private var saveAsInput = ""
    @State private var isShowingLeaveConfirm = false
    @State private var isTranslationMode = false
    @State private var alert: EditorAlert?
    @State private var successTick = 0
    @State private var failureTick = 0

    init(
        serverID: Int,
        path: String,
        fileName: String,
        onRequireTasks: @escaping () -> Void = {}
    ) {
        self.serverID = serverID
        self.initialPath = path
        self.initialName = fileName
        self.onRequireTasks = onRequireTasks
        _path = State(initialValue: path)
        _fileName = State(initialValue: fileName)
        _language = State(initialValue: SyntaxLanguage.detect(fileName: fileName))
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("正在读取文件…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                ContentUnavailableView {
                    Label("无法打开文件", systemImage: "doc.questionmark")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("重试") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                editorContent
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .task { await load() }
        .sheet(isPresented: $isShowingSaveAs) { saveAsSheet }
        .sheet(isPresented: $isShowingGotoLine) { gotoLineSheet }
        .sheet(isPresented: $isTranslationMode) {
            TranslationSheet(text: text) { line in
                if let range = controller.rangeOfLine(line, in: text) {
                    controller.select(range)
                }
            }
        }
        .confirmationDialog("放弃未保存的修改？", isPresented: $isShowingLeaveConfirm, titleVisibility: .visible) {
            Button("保存并退出") {
                Task {
                    await save()
                    if !hasUnsavedChanges { dismiss() }
                }
            }
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前文件有未保存的修改，退出后将丢失。")
        }
        .alert(
            alert?.title ?? "",
            isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            ),
            presenting: alert
        ) { alert in
            if case .tasks = alert {
                Button("查看任务") { onRequireTasks() }
            }
            Button("好", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: failureTick)
    }

    // MARK: - 主体

    private var editorContent: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()

            if isFindVisible {
                FindReplaceBar(
                    query: $findQuery,
                    replacement: $replaceQuery,
                    options: $findOptions,
                    matchCount: matches.count,
                    currentIndex: matches.isEmpty ? 0 : currentMatch + 1,
                    onPrevious: findPrevious,
                    onNext: findNext,
                    onReplace: replaceCurrent,
                    onReplaceAll: replaceAll,
                    onClose: {
                        withAnimation(.snappy) { isFindVisible = false }
                    }
                )
                Divider()
            }

            CodeEditorView(
                text: $text,
                language: language,
                isLineWrappingEnabled: isLineWrappingEnabled,
                matches: isFindVisible ? matches : [],
                currentMatch: isFindVisible && currentMatch < matches.count ? matches[currentMatch] : nil,
                controller: controller,
                onSelectionChange: { selection = $0 }
            )
        }
        .onChange(of: findQuery) { _, _ in refreshMatches(resetSelection: true) }
        .onChange(of: findOptions) { _, _ in refreshMatches(resetSelection: true) }
        .onChange(of: text) { _, _ in
            guard isFindVisible else { return }
            refreshMatches(resetSelection: false)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if hasUnsavedChanges {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("有未保存的修改")
            }

            Text(fileName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(verbatim: caretText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(encoding.title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(lineEnding.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if hasUnsavedChanges {
                    isShowingLeaveConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("返回")
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndo)
            .accessibilityLabel("撤销")

            Button {
                controller.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!controller.canRedo)
            .accessibilityLabel("重做")

            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .disabled(isSaving || isLoading || !hasUnsavedChanges)
            .accessibilityLabel("保存")

            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("更多")
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Menu("文档") {
            Button {
                saveAsInput = path
                isShowingSaveAs = true
            } label: {
                Label("另存为…", systemImage: "doc.on.doc")
            }

            Button {
                Task { await reload() }
            } label: {
                Label("重新加载文件", systemImage: "arrow.clockwise")
            }

            Menu("指定编码重新加载") {
                ForEach(TextEncoding.allCases) { item in
                    Button(item.title) {
                        Task { await reload(reinterpretingAs: item) }
                    }
                }
            }

            Menu("指定保存的编码") {
                ForEach(TextEncoding.allCases) { item in
                    Button {
                        encoding = item
                    } label: {
                        if item == encoding {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }

            Menu("换行符") {
                ForEach(LineEnding.allCases) { item in
                    Button {
                        lineEnding = item
                    } label: {
                        if item == lineEnding {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }
        }

        Menu("搜索") {
            Button {
                withAnimation(.snappy) { isFindVisible = true }
            } label: {
                Label("查找与替换…", systemImage: "magnifyingglass")
            }
            Button("查找下一个") { findNext() }
            Button("查找上一个") { findPrevious() }
            Divider()
            Button("全部替换") { replaceAll() }
                .disabled(findQuery.isEmpty)
        }

        Menu("语法") {
            ForEach(SyntaxLanguage.allCases) { item in
                Button {
                    language = item
                } label: {
                    if item == language {
                        Label(item.title, systemImage: "checkmark")
                    } else {
                        Text(item.title)
                    }
                }
            }
        }

        Button {
            gotoLineInput = "\(caret.line)"
            isShowingGotoLine = true
        } label: {
            Label("转到指定行…", systemImage: "text.line.last.and.arrowtriangle.forward")
        }

        Button {
            isTranslationMode = true
        } label: {
            Label("翻译模式…", systemImage: "character.bubble")
        }

        Toggle(isOn: $isLineWrappingEnabled) {
            Label("自动换行", systemImage: "text.alignleft")
        }
    }

    // MARK: - 弹层

    private var saveAsSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("保存路径", text: $saveAsInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                } footer: {
                    Text("以「/」开头的完整路径，例如 /plugins/config.yml。")
                }
            }
            .navigationTitle("另存为")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isShowingSaveAs = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let target = saveAsInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        isShowingSaveAs = false
                        Task { await saveAs(to: target) }
                    }
                    .disabled(!saveAsInput.trimmingCharacters(in: .whitespaces).hasPrefix("/"))
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    private var gotoLineSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("行号", text: $gotoLineInput)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("转到指定行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isShowingGotoLine = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("跳转") {
                        let line = Int(gotoLineInput.trimmingCharacters(in: .whitespaces)) ?? 0
                        isShowingGotoLine = false
                        if let range = controller.rangeOfLine(line, in: text) {
                            controller.select(range)
                        } else {
                            alert = .message("文件只有 \(lineCount) 行，无法跳转到第 \(line) 行。")
                        }
                    }
                    .disabled(Int(gotoLineInput.trimmingCharacters(in: .whitespaces)) == nil)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - 读取 / 保存

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let content = try await model.fileContent(serverID: serverID, path: path)
            lineEnding = LineEnding.detect(in: content)
            let normalized = LineEnding.normalized(content)
            text = normalized
            savedText = normalized
            language = SyntaxLanguage.detect(fileName: fileName)
        } catch let error as APIError {
            if case .forbidden(let message) = error, message.contains("任务队列") {
                loadError = "实例正在执行任务，暂时无法读取文件。稍后重试，或先去任务页查看进度。"
            } else {
                loadError = error.message
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// 重新读取。`encoding` 不为空时，把收到的字符按单字节回填后重新解码，用于修乱码。
    private func reload(reinterpretingAs encoding: TextEncoding? = nil) async {
        guard !isSaving else { return }
        if hasUnsavedChanges {
            alert = .message("请先保存或撤销当前修改，再重新加载文件。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var content = try await model.fileContent(serverID: serverID, path: path)
            let detected = LineEnding.detect(in: content)
            content = LineEnding.normalized(content)

            if let encoding {
                guard let fixed = encoding.reinterpret(content) else {
                    failureTick += 1
                    alert = .message("该文件无法按 \(encoding.title) 解码，已保持原内容。")
                    return
                }
                content = LineEnding.normalized(fixed)
                self.encoding = encoding
            }

            text = content
            savedText = content
            lineEnding = detected
            matches = []
            controller.select(NSRange(location: 0, length: 0))
            successTick += 1
        } catch let error as APIError {
            failureTick += 1
            handle(error)
        } catch {
            failureTick += 1
            alert = .message(error.localizedDescription)
        }
    }

    private func save(to targetPath: String? = nil) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let target = targetPath ?? path
        do {
            try await model.saveFileContent(
                serverID: serverID,
                path: target,
                content: lineEnding.applying(to: text)
            )
            if let targetPath {
                path = targetPath
                fileName = RemotePath.lastComponent(targetPath)
                language = SyntaxLanguage.detect(fileName: fileName)
            }
            savedText = text
            successTick += 1
        } catch let error as APIError {
            failureTick += 1
            handle(error)
        } catch {
            failureTick += 1
            alert = .message(error.localizedDescription)
        }
    }

    private func saveAs(to target: String) async {
        guard target.hasPrefix("/") else {
            alert = .message("保存路径需要以「/」开头。")
            return
        }
        await save(to: target)
    }

    // MARK: - 查找替换

    private func refreshMatches(resetSelection: Bool) {
        guard isFindVisible, !findQuery.isEmpty else {
            matches = []
            currentMatch = 0
            return
        }

        let found = TextSearch.ranges(in: text, query: findQuery, options: findOptions)
        matches = found

        if resetSelection {
            currentMatch = 0
            if let first = found.first {
                controller.select(first)
            }
        } else if currentMatch >= found.count {
            currentMatch = max(0, found.count - 1)
        }
    }

    private func findNext() {
        guard !matches.isEmpty else {
            refreshMatches(resetSelection: true)
            return
        }
        currentMatch = (currentMatch + 1) % matches.count
        controller.select(matches[currentMatch])
    }

    private func findPrevious() {
        guard !matches.isEmpty else {
            refreshMatches(resetSelection: true)
            return
        }
        currentMatch = (currentMatch - 1 + matches.count) % matches.count
        controller.select(matches[currentMatch])
    }

    private func replaceCurrent() {
        guard currentMatch < matches.count, !matches.isEmpty else { return }
        let range = matches[currentMatch]
        matches.remove(at: currentMatch)
        controller.replace(range: range, with: replaceQuery)
        if currentMatch >= matches.count {
            currentMatch = 0
        }
    }

    private func replaceAll() {
        guard !findQuery.isEmpty else { return }
        let replaced = TextSearch.replacingAll(
            in: text,
            query: findQuery,
            replacement: replaceQuery,
            options: findOptions
        )
        guard replaced != text else { return }
        controller.replaceAll(with: replaced)
        successTick += 1
    }

    // MARK: - 辅助

    private var hasUnsavedChanges: Bool { text != savedText }

    private var caret: (line: Int, column: Int) {
        EditorController.lineAndColumn(at: selection.location, in: text)
    }

    /// 光标位置；有选中内容时显示起止位置，例如 `1:1–3:4`。
    private var caretText: String {
        let start = caret
        guard selection.length > 0 else {
            return "\(start.line):\(start.column)"
        }
        let end = EditorController.lineAndColumn(
            at: selection.location + selection.length,
            in: text
        )
        return "\(start.line):\(start.column)–\(end.line):\(end.column)"
    }

    private var lineCount: Int {
        max(1, text.reduce(0) { $1 == "\n" ? $0 + 1 : $0 } + (text.hasSuffix("\n") ? 1 : 0))
    }

    private func handle(_ error: APIError) {
        switch error {
        case .forbidden(let message) where message.contains("任务队列"):
            alert = .tasks(message)
        case .forbidden(let message):
            alert = .message(message)
        default:
            alert = .message(error.message)
        }
    }
}

// MARK: - 弹窗数据

private enum EditorAlert: Identifiable {
    case message(String)
    case tasks(String)

    var id: String {
        switch self {
        case .message(let text): return "message-\(text)"
        case .tasks(let text): return "tasks-\(text)"
        }
    }

    var title: String {
        switch self {
        case .message: return "提示"
        case .tasks: return "实例正在执行任务"
        }
    }

    var message: String {
        switch self {
        case .message(let text), .tasks(let text): return text
        }
    }
}

// MARK: - 查找替换条

private struct FindReplaceBar: View {
    @Binding var query: String
    @Binding var replacement: String
    @Binding var options: FindOptions
    let matchCount: Int
    let currentIndex: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void
    let onClose: () -> Void

    @FocusState private var isQueryFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                field("查找", text: $query)
                    .focused($isQueryFocused)

                Text(verbatim: matchCount == 0 ? "无结果" : "\(currentIndex)/\(matchCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42, alignment: .trailing)

                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                }
                .disabled(matchCount == 0)

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                }
                .disabled(matchCount == 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                field("替换为", text: $replacement)

                Button("替换") { onReplace() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(matchCount == 0)

                Button("全部") { onReplaceAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(matchCount == 0)
            }

            HStack(spacing: 6) {
                optionChip("Aa", isOn: options.isCaseSensitive) {
                    options.isCaseSensitive.toggle()
                }
                optionChip("全词", isOn: options.isWholeWord) {
                    options.isWholeWord.toggle()
                }
                optionChip(".*", isOn: options.usesRegularExpression) {
                    options.usesRegularExpression.toggle()
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear { isQueryFocused = true }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.callout)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func optionChip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isOn ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                    in: Capsule()
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
