//
//  PointHistoryView.swift
//  simpfun
//

import SwiftUI

struct PointHistoryView: View {
    @Environment(AppModel.self) private var model

    @State private var records: [PointRecord] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(records) { record in
                HistoryRow(
                    comment: record.comment,
                    change: record.point,
                    balance: record.pointLeft,
                    createTime: record.createTime
                )
            }
        }
        .listStyle(.insetGrouped)
        .overlay { placeholder }
        .navigationTitle("积分明细")
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    @ViewBuilder
    private var placeholder: some View {
        if records.isEmpty {
            if isLoading && !hasLoaded {
                ProgressView("正在加载积分明细…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("无法加载积分明细", systemImage: "exclamationmark.triangle")
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
                    "暂无积分记录",
                    systemImage: "sparkles",
                    description: Text("暂时没有积分变动记录。")
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
            records = try await model.loadPointHistory()
            errorMessage = nil
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        PointHistoryView()
            .environment(AppModel())
    }
}
