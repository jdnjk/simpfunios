//
//  KindSelectionView.swift
//  simpfun
//

import SwiftUI

struct KindSelectionView: View {
    let mirror: MirrorType
    let game: Game

    @Environment(AppModel.self) private var model
    @State private var kinds: [GameKind] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var visibleCount = 10

    private var filteredKinds: [GameKind] {
        guard !searchText.isEmpty else { return kinds }
        return kinds.filter { kind in
            kind.name.localizedCaseInsensitiveContains(searchText)
                || (kind.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var visibleKinds: [GameKind] {
        Array(filteredKinds.prefix(visibleCount))
    }

    private var remainingCount: Int {
        max(0, filteredKinds.count - visibleCount)
    }

    var body: some View {
        List {
            ForEach(visibleKinds) { kind in
                NavigationLink(value: CreateInstanceStep.version(mirror, kind)) {
                    row(kind)
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
            if kinds.isEmpty {
                ListStateView(
                    isLoading: isLoading,
                    hasLoaded: hasLoaded,
                    errorMessage: errorMessage,
                    emptyTitle: "暂无服务端",
                    emptyDescription: "该类别下暂时没有可用的服务端。"
                ) {
                    Task { await load(force: true) }
                }
            } else if filteredKinds.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "搜索服务端")
        .onChange(of: searchText) { _, _ in
            visibleCount = 10
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func row(_ kind: GameKind) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteIcon(
                url: kind.imageURL,
                fallbackSystemImage: mirror.isCustom ? "puzzlepiece.extension" : "server.rack"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(kind.name)
                    .font(.headline)

                if let description = kind.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(MarkdownText.attributed(description, limit: 200))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(10)
                        .tint(Color.accentColor)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            kinds = try await model.loadGameKinds(gameID: game.id, custom: mirror.isCustom)
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
