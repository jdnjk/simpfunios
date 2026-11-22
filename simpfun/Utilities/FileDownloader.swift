//
//  FileDownloader.swift
//  simpfun
//

import Foundation
import Observation

/// 应用内下载器：把服务端给的直链拉成沙盒里的本地文件，并把进度暴露给界面。
///
/// 文件统一落在 `Documents/下载/`，配合 `UIFileSharingEnabled`，
/// 可在「文件」App 的「我的 iPhone › simpfun › 下载」里直接看到。
@MainActor
@Observable
final class FileDownloader {
    struct Progress: Equatable {
        let fileName: String
        var received: Int64
        /// 服务端没给 `Content-Length` 时为 0，此时界面只显示已下载的字节数。
        var total: Int64

        var fraction: Double? {
            guard total > 0 else { return nil }
            return min(1, Double(received) / Double(total))
        }
    }

    private(set) var progress: Progress?

    var isDownloading: Bool { progress != nil }

    /// 下载并返回本地文件地址。同名文件会自动加序号，不会覆盖上一次的下载结果。
    func download(from url: URL, fileName: String) async throws -> URL {
        let name = Self.safeName(fileName)
        progress = Progress(fileName: name, received: 0, total: 0)

        defer { progress = nil }

        let directory = Self.downloadDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = Self.uniqueURL(in: directory, name: name)

        let coordinator = DownloadCoordinator(destination: destination) { [weak self] received, total in
            Task { @MainActor in
                guard let self, var current = self.progress else { return }
                current.received = received
                current.total = total
                self.progress = current
            }
        }

        do {
            return try await coordinator.start(url)
        } catch let error as DownloadError {
            throw error
        } catch let error as URLError {
            throw DownloadError.network(error)
        }
    }

    var downloadDirectory: URL { Self.downloadDirectory }

    static var downloadDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("下载", isDirectory: true)
    }

    /// 去掉路径分隔符等文件系统不接受的字符，避免 `name` 里带 `/` 时写文件失败。
    static func safeName(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "download" : cleaned
    }

    /// `a.jar` → `a (1).jar`：同名文件已存在时递增，保留扩展名便于再次导出。
    static func uniqueURL(in directory: URL, name: String) -> URL {
        let candidate = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 1
        while true {
            let nextName = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let url = directory.appendingPathComponent(nextName)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }
}

enum DownloadError: LocalizedError {
    case http(Int)
    case network(URLError)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(let code):
            return "下载失败：服务器返回 HTTP \(code)。"
        case .network(let error):
            return "下载失败：\(error.localizedDescription)"
        case .empty:
            return "下载失败：文件内容为空。"
        }
    }
}

/// `URLSessionDownloadDelegate` 的回调在后台队列，这里只负责搬运文件和上报进度，
/// 界面层的状态更新由 `FileDownloader` 切回主线程完成。
private final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let onProgress: (Int64, Int64) -> Void

    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?

    init(destination: URL, onProgress: @escaping (Int64, Int64) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
        super.init()
    }

    func start(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            // 大文件（整合包、地图）下载慢，资源超时给足。
            configuration.timeoutIntervalForResource = 900
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 0
        onProgress(totalBytesWritten, total)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 出错时服务端同样会下发内容（HTML 错误页），先看状态码再落盘。
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(DownloadError.http(http.statusCode)))
            return
        }

        // 系统会在本方法返回后删除 `location`，必须同步搬走。
        do {
            let fileManager = FileManager.default
            let size = (try? fileManager.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
            guard size > 0 else {
                finish(.failure(DownloadError.empty))
                return
            }

            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if let urlError = error as? URLError {
            finish(.failure(DownloadError.network(urlError)))
        } else {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        session?.invalidateAndCancel()
        continuation.resume(with: result)
    }
}
