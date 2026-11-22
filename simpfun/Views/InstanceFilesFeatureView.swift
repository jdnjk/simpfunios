//
//  InstanceFilesFeatureView.swift
//  simpfun
//

import Observation
import SwiftUI
import UIKit

/// 目录导航的目标值。
struct RemoteDirectory: Hashable {
    let path: String
}

/// 跨目录共享的剪切板：记录被剪切的绝对路径，只在内存里有效。
@Observable
final class FileClipboard {
    private(set) var paths: [String] = []
    private(set) var sourceDirectory = ""

    var isEmpty: Bool { paths.isEmpty }
    var count: Int { paths.count }

    func cut(_ paths: [String], from directory: String) {
        self.paths = paths
        self.sourceDirectory = directory
    }

    func clear() {
        paths = []
        sourceDirectory = ""
    }
}

/// 文件功能的入口：固定从根目录开始，并注册子目录的导航目标。
struct InstanceFilesFeatureView: View {
    let serverID: Int
    var onRequireTasks: () -> Void = {}

    @State private var clipboard = FileClipboard()
    @State private var downloader = FileDownloader()

    var body: some View {
        FileBrowserView(serverID: serverID, path: "/", onRequireTasks: onRequireTasks)
            .environment(clipboard)
            .environment(downloader)
            .navigationDestination(for: RemoteDirectory.self) { directory in
                FileBrowserView(
                    serverID: serverID,
                    path: directory.path,
                    onRequireTasks: onRequireTasks
                )
                .environment(clipboard)
                .environment(downloader)
            }
    }
}

/// 单个目录的列表。根目录与子目录复用同一个视图。
struct FileBrowserView: View {
    let serverID: Int
    let path: String
    var onRequireTasks: () -> Void = {}

    @Environment(AppModel.self) private var model
    @Environment(FileClipboard.self) private var clipboard
    @Environment(FileDownloader.self) private var downloader

    @State private var files: [RemoteFile] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var isBlockedByTask = false
    @State private var isEditing = false
    @State private var selection = Set<String>()
    @State private var isBusy = false
    @State private var alert: FileAlert?
    @State private var dialog: FileDialog?
    @State private var textInput = ""
    @State private var downloadedFile: DownloadedFile?
    @State private var editingFile: RemoteFile?

    var body: some View {
        Group {
            if hasLoaded {
                content
            } else if isLoading {
                ProgressView("正在加载文件…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay { busyOverlay }
        .task { await load() }
        // 从子目录返回时刷新一次，避免子目录里的重命名/删除在这里显示过期内容。
        .onAppear {
            guard hasLoaded else { return }
            Task { await load(force: true) }
        }
        .alert(
            alert?.title ?? "",
            isPresented: Binding(
                get: { alert != nil },
                set: { isPresented in
                    if !isPresented { alert = nil }
                }
            ),
            presenting: alert
        ) { alert in
            alertButtons(for: alert)
        } message: { alert in
            Text(alert.message)
        }
        .confirmationDialog(
            dialog?.title ?? "",
            isPresented: Binding(
                get: { dialog != nil },
                set: { isPresented in
                    if !isPresented { dialog = nil }
                }
            ),
            presenting: dialog
        ) { dialog in
            dialogButtons(for: dialog)
        } message: { dialog in
            Text(dialog.message)
        }
        .sheet(item: $downloadedFile) { file in
            FileDownloadSheet(file: file)
        }
        .navigationDestination(item: $editingFile) { file in
            FileEditorView(
                serverID: serverID,
                path: file.path(in: path),
                fileName: file.name,
                onRequireTasks: onRequireTasks
            )
        }
    }

    // MARK: - 列表

    private var content: some View {
        List(selection: $selection) {
            Section {
                if files.isEmpty {
                    Text("此目录是空的")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedFiles) { file in
                        row(file)
                    }
                }
            } header: {
                Text(verbatim: path)
                    .font(.caption.monospaced())
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable { await load(force: true) }
        .disabled(isBusy)
    }

    @ViewBuilder
    private func row(_ file: RemoteFile) -> some View {
        let fullPath = file.path(in: path)

        if isEditing {
            fileRow(file, showsMenu: false)
                .tag(fullPath)
                .contextMenu { rowMenu(file) }
                .swipeActions(edge: .trailing) { swipeActions(file) }
        } else if file.isFile {
            // 行本身保持普通内容，只挂 contextMenu；右侧的菜单按钮负责「点一下就出操作」。
            // 不能把整行做成 Menu 的 label，否则长按弹出菜单时行内容会被摘走、看起来文件消失。
            fileRow(file, showsMenu: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    open(file)
                }
                .contextMenu { rowMenu(file) }
                .swipeActions(edge: .trailing) { swipeActions(file) }
        } else {
            NavigationLink(value: RemoteDirectory(path: fullPath)) {
                fileRow(file, showsMenu: false)
            }
            .tag(fullPath)
            .contextMenu { rowMenu(file) }
            .swipeActions(edge: .trailing) { swipeActions(file) }
        }
    }

    private func fileRow(_ file: RemoteFile, showsMenu: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: file))
                .font(.system(size: 18))
                .foregroundStyle(tint(for: file))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let detail = detailText(for: file) {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if showsMenu {
                fileMenu(file)
            }
        }
        .padding(.vertical, 2)
    }

    private func fileMenu(_ file: RemoteFile) -> some View {
        Menu {
            rowMenu(file)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: "\(file.name) 的操作"))
    }

    /// 文件与文件夹共用的操作项；文件夹没有「解压 / 下载 / 创建副本」。
    @ViewBuilder
    private func rowMenu(_ file: RemoteFile) -> some View {
        let fullPath = file.path(in: path)

        if file.isFile {
            if file.isEditable {
                Button {
                    open(file)
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                }
            }

            // 不判断扩展名，任何文件都提供解压入口，能否解开交给服务端判断。
            Button {
                dialog = .unarchive(file)
            } label: {
                Label("解压", systemImage: "doc.zipper")
            }

            Button {
                Task { await download(file) }
            } label: {
                Label("下载", systemImage: "arrow.down.circle")
            }

            Divider()
        }

        Button {
            beginRename(file)
        } label: {
            Label("重命名", systemImage: "pencil")
        }

        if file.isFile {
            Button {
                Task { await duplicate(file) }
            } label: {
                Label("创建副本", systemImage: "plus.square.on.square")
            }
        }

        Button {
            dialog = .archive([fullPath])
        } label: {
            Label("压缩", systemImage: "archivebox")
        }

        Button {
            cut([fullPath])
        } label: {
            Label("剪切", systemImage: "scissors")
        }

        Divider()

        Button(role: .destructive) {
            dialog = .delete([fullPath])
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    /// 文件夹没有右侧按钮，用滑动手势补齐高频操作。
    @ViewBuilder
    private func swipeActions(_ file: RemoteFile) -> some View {
        let fullPath = file.path(in: path)

        Button(role: .destructive) {
            dialog = .delete([fullPath])
        } label: {
            Label("删除", systemImage: "trash")
        }

        Button {
            cut([fullPath])
        } label: {
            Label("剪切", systemImage: "scissors")
        }
        .tint(.orange)

        Button {
            beginRename(file)
        } label: {
            Label("重命名", systemImage: "pencil")
        }
        .tint(.blue)
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    beginCreate(.folder)
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }

                Button {
                    beginCreate(.file)
                } label: {
                    Label("新建文件", systemImage: "doc.badge.plus")
                }

                Divider()

                Button {
                    dialog = .fixPermission
                } label: {
                    Label("修复乱码与权限", systemImage: "wrench.and.screwdriver")
                }

                Button {
                    Task { await load(force: true) }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .disabled(isBusy)
        }

        if !files.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "完成" : "选择") {
                    withAnimation(.snappy) {
                        isEditing.toggle()
                        selection.removeAll()
                    }
                }
            }
        }
    }

    // MARK: - 底部操作条

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if isEditing, !selection.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        dialog = .archive(Array(selection))
                    } label: {
                        Label("压缩", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        cut(Array(selection))
                    } label: {
                        Label("剪切", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                    }

                    Button(role: .destructive) {
                        dialog = .delete(Array(selection))
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }

            if !clipboard.isEmpty {
                clipboardBar
            }
        }
    }

    private var clipboardBar: some View {
        HStack(spacing: 12) {
            Label {
                Text(verbatim: "已剪切 \(clipboard.count) 项")
            } icon: {
                Image(systemName: "scissors")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button("粘贴到这里") {
                Task { await paste() }
            }
            .font(.footnote.weight(.semibold))
            .disabled(isBusy)

            Button("取消") {
                clipboard.clear()
            }
            .font(.footnote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if let progress = downloader.progress {
            VStack(spacing: 10) {
                Text("正在下载")
                    .font(.subheadline.weight(.medium))

                Text(progress.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let fraction = progress.fraction {
                    ProgressView(value: fraction)
                        .frame(width: 180)

                    Text(verbatim: "\(Int(fraction * 100))% · \(Self.byteText(progress.received)) / \(Self.byteText(progress.total))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .padding(.vertical, 4)

                    Text(verbatim: Self.byteText(progress.received))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(22)
            .frame(width: 240)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if isBusy {
            ProgressView()
                .controlSize(.large)
                .padding(22)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private static func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label(
                isBlockedByTask ? "实例正在执行任务" : "无法加载目录",
                systemImage: isBlockedByTask ? "clock.badge.exclamationmark" : "exclamationmark.triangle"
            )
        } description: {
            Text(message)
        } actions: {
            if isBlockedByTask {
                Button("查看任务") { onRequireTasks() }
                    .buttonStyle(.borderedProminent)
            }
            Button("重试") {
                Task { await load(force: true) }
            }
        }
    }

    // MARK: - 弹窗

    @ViewBuilder
    private func alertButtons(for alert: FileAlert) -> some View {
        switch alert {
        case .message, .tasks:
            if case .tasks = alert {
                Button("查看任务") { onRequireTasks() }
            }
            Button("好", role: .cancel) {}

        case .rename(let file):
            TextField("新名称", text: $textInput)
            Button("取消", role: .cancel) {}
            Button("重命名") {
                Task { await rename(file) }
            }

        case .create(let mode):
            TextField("名称", text: $textInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("取消", role: .cancel) {}
            Button("创建") {
                Task { await create(mode) }
            }
        }
    }

    @ViewBuilder
    private func dialogButtons(for dialog: FileDialog) -> some View {
        switch dialog {
        case .delete(let paths):
            Button("删除 \(paths.count) 项", role: .destructive) {
                Task { await delete(paths) }
            }
            Button("取消", role: .cancel) {}

        case .archive(let paths):
            Button("压缩为 7z") {
                Task { await archive(paths, format: .sevenZip) }
            }
            Button("压缩为 zip") {
                Task { await archive(paths, format: .zip) }
            }
            Button("取消", role: .cancel) {}

        case .unarchive(let file):
            Button("解压到当前目录") {
                Task { await unarchive(file) }
            }
            Button("取消", role: .cancel) {}

        case .fixPermission:
            Button("开始修复") {
                Task { await fixPermission() }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 操作

    private func beginRename(_ file: RemoteFile) {
        textInput = file.name
        alert = .rename(file)
    }

    private func beginCreate(_ mode: FileCreateMode) {
        textInput = mode == .folder ? "新建文件夹" : ""
        alert = .create(mode)
    }

    private func cut(_ paths: [String]) {
        clipboard.cut(paths, from: path)
        selection.removeAll()
        isEditing = false
    }

    private func unarchive(_ file: RemoteFile) async {
        await perform {
            try await model.unarchiveFile(serverID: serverID, root: path, file: file.name)
        }
    }

    private func archive(_ paths: [String], format: ArchiveFormat) async {
        let names = paths.map(RemotePath.lastComponent)
        await perform {
            try await model.archiveFiles(
                serverID: serverID,
                root: path,
                files: names,
                format: format
            )
        }
    }

    private func delete(_ paths: [String]) async {
        await perform {
            try await model.deleteFiles(serverID: serverID, paths: paths)
        }
    }

    private func rename(_ file: RemoteFile) async {
        let name = trimmedInput
        guard !name.isEmpty else { return }
        guard !name.contains("/") else {
            alert = .message("名称不能包含「/」。")
            return
        }
        guard name != file.name else { return }

        let origin = file.path(in: path)
        let target = RemotePath.join(path, name)
        await perform {
            try await model.renameFile(serverID: serverID, origin: origin, target: target)
        }
    }

    private func duplicate(_ file: RemoteFile) async {
        let location = file.path(in: path)
        await perform {
            try await model.copyFile(serverID: serverID, location: location)
        }
    }

    private func create(_ mode: FileCreateMode) async {
        let name = trimmedInput
        guard !name.isEmpty else { return }
        guard !name.contains("/") else {
            alert = .message("名称不能包含「/」。")
            return
        }

        let root = RemotePath.directoryForm(path)
        await perform {
            try await model.createFileEntry(
                serverID: serverID,
                mode: mode,
                root: root,
                name: name
            )
        }
    }

    private func paste() async {
        let paths = clipboard.paths
        guard !paths.isEmpty else { return }
        let target = path

        await perform {
            try await model.pasteFiles(serverID: serverID, paths: paths, target: target)
            clipboard.clear()
        }
    }

    private func fixPermission() async {
        await perform(
            { try await model.fixFilePermissionAndCharset(serverID: serverID) },
            success: "已提交修复，稍后刷新即可查看结果。"
        )
    }

    /// 点击文件：文本类直接进编辑器，二进制文件给一句说明。
    private func open(_ file: RemoteFile) {
        guard !isBusy else { return }
        if file.isEditable {
            editingFile = file
        } else {
            alert = .message("「\(file.name)」不是文本文件，无法在应用内编辑。可以下载后用其他工具处理。")
        }
    }

    private func download(_ file: RemoteFile) async {
        guard !isBusy, !downloader.isDownloading else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let link = try await model.fileDownloadURL(
                serverID: serverID,
                path: file.path(in: path)
            )
            let local = try await downloader.download(from: link, fileName: file.name)
            let bytes = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? Int64) ?? 0
            downloadedFile = DownloadedFile(url: local, bytes: bytes)
        } catch let error as APIError {
            handle(error)
        } catch {
            alert = .message(error.localizedDescription)
        }
    }

    /// 所有写操作共用：防重入、成功后刷新目录、失败按类型提示。
    private func perform(_ operation: @escaping () async throws -> Void, success: String? = nil) async {
        guard !isBusy else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
            selection.removeAll()
            await load(force: true)
            if let success {
                alert = .message(success)
            }
        } catch let error as APIError {
            handle(error)
        } catch {
            alert = .message(error.localizedDescription)
        }
    }

    private func handle(_ error: APIError) {
        switch error {
        case .forbidden(let message) where message.contains("任务队列"):
            alert = .tasks(message)
        case .ipNotVerified, .verificationRequired, .notSignedIn, .invalidToken:
            // AppModel 已经弹出小程序验证或登录失效提示，这里不再重复。
            break
        default:
            alert = .message(error.message)
        }
    }

    // MARK: - 加载

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            files = try await model.loadFileList(serverID: serverID, path: path)
            errorMessage = nil
            isBlockedByTask = false
            hasLoaded = true
        } catch let error as APIError {
            if case .forbidden(let message) = error, message.contains("任务队列") {
                isBlockedByTask = true
            }
            errorMessage = error.message
            // 首次加载失败时展示错误页；已有内容时保留列表，避免操作后界面被清空。
            if files.isEmpty {
                hasLoaded = false
            }
        } catch {
            errorMessage = error.localizedDescription
            if files.isEmpty {
                hasLoaded = false
            }
        }
    }

    // MARK: - 展示辅助

    private var title: String {
        path == "/" ? "根目录" : RemotePath.lastComponent(path)
    }

    private var trimmedInput: String {
        textInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedFiles: [RemoteFile] {
        files.sorted { lhs, rhs in
            if lhs.isFile != rhs.isFile {
                return !lhs.isFile
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func detailText(for file: RemoteFile) -> String? {
        guard file.isFile else { return nil }

        var parts: [String] = []
        if let size = file.size, size >= 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        if let modified = file.modifiedAt, !modified.isEmpty {
            parts.append(modified)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func fileExtension(_ file: RemoteFile) -> String {
        (file.name as NSString).pathExtension.lowercased()
    }

    private func icon(for file: RemoteFile) -> String {
        guard file.isFile else { return "folder.fill" }

        switch fileExtension(file) {
        case "zip", "7z", "rar", "tar", "gz", "xz", "bz2":
            return "doc.zipper"
        case "jar":
            return "shippingbox.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp":
            return "photo.fill"
        case "json", "yml", "yaml", "toml", "properties", "conf", "cfg", "ini", "xml":
            return "curlybraces"
        case "sh", "bat", "command":
            return "terminal"
        case "txt", "md", "log", "csv":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    private func tint(for file: RemoteFile) -> Color {
        guard file.isFile else { return .accentColor }

        switch fileExtension(file) {
        case "zip", "7z", "rar", "tar", "gz", "xz", "bz2":
            return .orange
        case "jar":
            return .brown
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp":
            return .purple
        case "sh", "bat", "command":
            return .green
        default:
            return .secondary
        }
    }
}

// MARK: - 弹窗数据

private enum FileAlert: Identifiable {
    case message(String)
    case tasks(String)
    case rename(RemoteFile)
    case create(FileCreateMode)

    var id: String {
        switch self {
        case .message(let text):
            return "message-\(text)"
        case .tasks(let text):
            return "tasks-\(text)"
        case .rename(let file):
            return "rename-\(file.name)"
        case .create(let mode):
            return "create-\(mode.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .message:
            return "提示"
        case .tasks:
            return "实例正在执行任务"
        case .rename:
            return "重命名"
        case .create(let mode):
            return mode.title
        }
    }

    var message: String {
        switch self {
        case .message(let text), .tasks(let text):
            return text
        case .rename(let file):
            return "为「\(file.name)」输入新的名称。"
        case .create(let mode):
            return mode == .folder ? "在当前目录新建一个文件夹。" : "在当前目录新建一个空文件。"
        }
    }
}

private enum FileDialog: Identifiable {
    case delete([String])
    case archive([String])
    case unarchive(RemoteFile)
    case fixPermission

    var id: String {
        switch self {
        case .delete(let paths):
            return "delete-\(paths.joined(separator: ","))"
        case .archive(let paths):
            return "archive-\(paths.joined(separator: ","))"
        case .unarchive(let file):
            return "unarchive-\(file.name)"
        case .fixPermission:
            return "fix-permission"
        }
    }

    var title: String {
        switch self {
        case .delete:
            return "删除"
        case .archive:
            return "压缩"
        case .unarchive:
            return "解压"
        case .fixPermission:
            return "修复乱码与权限"
        }
    }

    var message: String {
        switch self {
        case .delete(let paths):
            return paths.count == 1
                ? "「\(RemotePath.lastComponent(paths[0]))」将被永久删除，无法恢复。"
                : "\(paths.count) 个项目将被永久删除，无法恢复。"
        case .archive(let paths):
            return paths.count == 1
                ? "把「\(RemotePath.lastComponent(paths[0]))」压缩到当前目录，请选择格式。"
                : "把选中的 \(paths.count) 个项目压缩到当前目录，请选择格式。"
        case .unarchive(let file):
            return "「\(file.name)」将解压到当前目录，同名文件会被覆盖。"
        case .fixPermission:
            return "尝试修复中文乱码与文件权限，过程中实例文件可能短暂不可用。"
        }
    }
}
