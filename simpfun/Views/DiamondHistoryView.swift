//
//  DiamondHistoryView.swift
//  simpfun
//

import SwiftUI

struct DiamondHistoryView: View {
    @Environment(AppModel.self) private var model

    @State private var records: [DiamondRecord] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(records) { record in
                HistoryRow(
                    comment: record.comment,
                    change: record.diamond,
                    balance: record.diamondLeft,
                    createTime: record.createTime
                )
            }
        }
        .listStyle(.insetGrouped)
        .overlay { placeholder }
        .navigationTitle("钻石明细")
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    @ViewBuilder
    private var placeholder: some View {
        if records.isEmpty {
            if isLoading && !hasLoaded {
                ProgressView("正在加载钻石明细…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("无法加载钻石明细", systemImage: "exclamationmark.triangle")
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
                    "暂无钻石记录",
                    systemImage: "diamond",
                    description: Text("暂时没有钻石变动记录。")
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
            records = try await model.loadDiamondHistory()
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
        DiamondHistoryView()
            .environment(AppModel())
    }
}
