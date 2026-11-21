//
//  VersionSelectionView.swift
//  simpfun
//

import SwiftUI

struct VersionSelectionView: View {
    let mirror: MirrorType
    let kind: GameKind

    @Environment(AppModel.self) private var model
    @State private var versions: [GameVersion] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var visibleCount = 10

    private var visibleVersions: [GameVersion] {
        Array(versions.prefix(visibleCount))
    }

    private var remainingCount: Int {
        max(0, versions.count - visibleCount)
    }

    var body: some View {
        List {
            ForEach(visibleVersions) { version in
                NavigationLink(value: CreateInstanceStep.spec(mirror, version)) {
                    row(version)
                }
            }

            if remainingCount > 0 {
                Section {
                    Button {
                        visibleCount += 10
                    } label: {
                        HStack {
                            Spacer()
                            Text(verbatim: "加载更多（剩余 \(remainingCount)）")
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if versions.isEmpty {
                ListStateView(
                    isLoading: isLoading,
                    hasLoaded: hasLoaded,
                    errorMessage: errorMessage,
                    emptyTitle: "暂无版本",
                    emptyDescription: "该服务端暂时没有可用版本。"
                ) {
                    Task { await load(force: true) }
                }
            }
        }
        .navigationTitle(kind.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func row(_ version: GameVersion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(version.name)
                .font(.headline)

            if let description = version.description,
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(MarkdownText.attributed(description, limit: 200))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(10)
                    .tint(Color.accentColor)
            }

            if mirror.isCustom {
                HStack(spacing: 12) {
                    if let recommendSetting = version.recommendSetting,
                       !recommendSetting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: "推荐配置：\(recommendSetting)")
                    }
                    if let size = version.formattedSize {
                        Text(verbatim: "大小：\(size)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            versions = try await model.loadGameVersions(kindID: kind.id, custom: mirror.isCustom)
                .sorted { $0.id > $1.id }
            errorMessage = nil
            visibleCount = 10
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
