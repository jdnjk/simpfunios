//
//  GameSelectionView.swift
//  simpfun
//

import SwiftUI

struct GameSelectionView: View {
    let mirror: MirrorType

    @Environment(AppModel.self) private var model
    @State private var games: [Game] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(games) { game in
                NavigationLink(value: CreateInstanceStep.kind(mirror, game)) {
                    HStack(spacing: 14) {
                        RemoteIcon(url: game.imageURL)

                        Text(game.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if games.isEmpty {
                ListStateView(
                    isLoading: isLoading,
                    hasLoaded: hasLoaded,
                    errorMessage: errorMessage,
                    emptyTitle: "暂无类别",
                    emptyDescription: "暂时没有可选的镜像类别。"
                ) {
                    Task { await load(force: true) }
                }
            }
        }
        .navigationTitle("选择类别")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            games = try await model.loadGames(custom: mirror.isCustom)
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
        GameSelectionView(mirror: .official)
            .environment(AppModel())
    }
}
