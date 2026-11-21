//
//  InstanceFeatureViews.swift
//  simpfun
//

import SwiftUI

enum InstanceFeature: String, CaseIterable, Identifiable {
    case terminal
    case files
    case reinstall
    case backup
    case management
    case statistics
    case tasks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            return "终端"
        case .files:
            return "文件"
        case .reinstall:
            return "重装"
        case .backup:
            return "备份"
        case .management:
            return "管理"
        case .statistics:
            return "统计"
        case .tasks:
            return "任务"
        }
    }

    var systemImage: String {
        switch self {
        case .terminal:
            return "terminal"
        case .files:
            return "folder.fill"
        case .reinstall:
            return "arrow.clockwise"
        case .backup:
            return "archivebox.fill"
        case .management:
            return "slider.horizontal.3"
        case .statistics:
            return "chart.bar.fill"
        case .tasks:
            return "list.bullet.rectangle"
        }
    }
}

struct InstanceDrawer: View {
    let detail: InstanceDetail
    let selectedFeature: InstanceFeature?
    let onSelect: (InstanceFeature?) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    row(nil, title: "概览", systemImage: "square.grid.2x2.fill")

                    Text("功能")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 18)
                        .padding(.bottom, 4)

                    ForEach(InstanceFeature.allCases) { feature in
                        row(feature, title: feature.title, systemImage: feature.systemImage)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.displayName)
                    .font(.headline)

                Text(verbatim: "实例 #\(detail.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let info = detail.gameInfo {
                    Text(info.gameName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(16)
    }

    private func row(
        _ feature: InstanceFeature?,
        title: String,
        systemImage: String
    ) -> some View {
        let isSelected = selectedFeature == feature

        return Button {
            onSelect(feature)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24)

                Text(title)
                    .font(.body)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct InstanceFeaturePlaceholderContent: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text("该功能正在开发中，敬请期待。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct InstanceBackupFeatureView: View {
    @State private var mode: BackupMode = .image

    private enum BackupMode: String, CaseIterable, Identifiable {
        case image
        case rollback

        var id: String { rawValue }

        var title: String {
            switch self {
            case .image:
                return "镜像备份"
            case .rollback:
                return "回档管理"
            }
        }

        var systemImage: String {
            switch self {
            case .image:
                return "externaldrive.fill"
            case .rollback:
                return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("备份类型", selection: $mode) {
                ForEach(BackupMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            InstanceFeaturePlaceholderContent(title: mode.title, systemImage: mode.systemImage)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct InstanceTasksFeatureView: View {
    let serverID: Int

    @State private var mode: TaskMode = .queue

    private enum TaskMode: String, CaseIterable, Identifiable {
        case queue
        case scheduled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .queue:
                return "队列任务"
            case .scheduled:
                return "计划任务"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("任务类型", selection: $mode) {
                ForEach(TaskMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            switch mode {
            case .queue:
                InstanceTasksView(serverID: serverID)
            case .scheduled:
                InstanceFeaturePlaceholderContent(
                    title: "计划任务",
                    systemImage: "calendar.badge.clock"
                )
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
