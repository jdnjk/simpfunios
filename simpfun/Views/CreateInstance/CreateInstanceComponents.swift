//
//  CreateInstanceComponents.swift
//  simpfun
//

import SwiftUI

struct RemoteIcon: View {
    let url: URL?
    var fallbackSystemImage: String = "shippingbox"
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: size * 0.45))
            .foregroundStyle(.secondary)
    }
}

struct ListStateView: View {
    let isLoading: Bool
    let hasLoaded: Bool
    let errorMessage: String?
    let emptyTitle: String
    let emptyDescription: String
    let retry: () -> Void

    var body: some View {
        if isLoading {
            ProgressView("正在加载…")
        } else if let errorMessage {
            ContentUnavailableView {
                Label("加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        } else if hasLoaded {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "tray",
                description: Text(emptyDescription)
            )
        } else {
            ProgressView()
        }
    }
}
