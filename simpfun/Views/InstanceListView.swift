//
//  InstanceListView.swift
//  simpfun
//

import SwiftUI

struct InstanceListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.instances) { instance in
                    InstanceRow(instance: instance)
                }
            }
            .listStyle(.insetGrouped)
            .overlay { placeholder }
            .refreshable { await model.refreshInstances(force: true) }
            .navigationTitle("实例")
        }
        .task {
            await model.refreshInstances()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if model.instances.isEmpty {
            if model.isLoadingInstances {
                ProgressView("正在加载实例…")
            } else if let message = model.instancesErrorMessage {
                ContentUnavailableView {
                    Label("无法加载实例", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("重试") {
                        Task { await model.refreshInstances(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if model.hasLoadedInstances {
                ContentUnavailableView(
                    "暂无实例",
                    systemImage: "server.rack",
                    description: Text("你还没有任何实例。")
                )
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    InstanceListView()
        .environment(AppModel())
}
