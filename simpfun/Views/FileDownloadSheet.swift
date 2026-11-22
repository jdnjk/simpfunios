//
//  FileDownloadSheet.swift
//  simpfun
//

import SwiftUI
import UIKit

/// 一次下载完成的产物：沙盒里的本地文件。
struct DownloadedFile: Identifiable {
    let id = UUID()
    let url: URL
    let bytes: Int64

    var name: String { url.lastPathComponent }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// 下载完成后的落盘入口：导出到「文件」App，或分享给其他 App。
///
/// iOS 不允许第三方 App 直接写入系统的「下载」文件夹，所以这里用系统的
/// 文档导出面板：用户选中「下载」再点「存储」，等价于直接下载到下载文件夹。
struct FileDownloadSheet: View {
    let file: DownloadedFile

    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                header

                VStack(spacing: 10) {
                    Button {
                        isExporting = true
                    } label: {
                        Label("存储到「文件」", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    ShareLink(item: file.url) {
                        Label("分享到其他 App", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("文件已保存在「文件」App 的「我的 iPhone › simpfun › 下载」中。想要放进系统的「下载」文件夹，点上面的按钮后选择「下载」再存储即可。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("下载完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isExporting) {
            DocumentExporter(url: file.url) {
                isExporting = false
                dismiss()
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)

            Text(file.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)

            Text(verbatim: file.sizeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// 把沙盒文件交给系统「文件」App：用户自行选择目标位置（含「下载」）。
struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL
    var onFinish: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // `asCopy: true` 让系统复制一份，App 自己保留原件。
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish()
        }
    }
}
