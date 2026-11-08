//
//  AnnouncementListView.swift
//  simpfun
//

import SwiftUI

struct AnnouncementListView: View {
    @Environment(AppModel.self) private var model

    @State private var announcements: [Announcement] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(announcements) { announcement in
                NavigationLink {
                    AnnouncementDetailView(announcement: announcement)
                } label: {
                    row(announcement)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { placeholder }
        .navigationTitle("公告")
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    private func row(_ announcement: Announcement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(announcement.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let createTime = announcement.createTime {
                    Text(createTime, format: .dateTime.year().month().day())
                }
                if let readTimes = announcement.readTimes {
                    Text(verbatim: "\(readTimes) 次阅读")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var placeholder: some View {
        if announcements.isEmpty {
            if isLoading && !hasLoaded {
                ProgressView("正在加载公告…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("无法加载公告", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") {
                        Task { await load(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if hasLoaded {
                ContentUnavailableView(
                    "暂无公告",
                    systemImage: "megaphone",
                    description: Text("暂时没有公告。")
                )
            } else {
                ProgressView()
            }
        }
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            announcements = try await model.loadAnnouncements()
            errorMessage = nil
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AnnouncementDetailView: View {
    let announcement: Announcement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(announcement.title)
                    .font(.title3.bold())

                if let createTime = announcement.createTime {
                    Text(createTime, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(announcement.renderedText)
                    .font(.body)
                    .tint(Color.accentColor)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AnnouncementListView()
            .environment(AppModel())
    }
}
