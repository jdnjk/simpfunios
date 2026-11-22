//
//  InstancePowerAction.swift
//  simpfun
//

import Foundation

/// 实例电源操作，对应 `POST /api/ins/{id}/power?action=...`。
enum InstancePowerAction: String, CaseIterable, Identifiable {
    case start
    case stop
    case restart
    case kill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start:
            return "启动"
        case .stop:
            return "停止"
        case .restart:
            return "重启"
        case .kill:
            return "强制停止"
        }
    }

    var systemImage: String {
        switch self {
        case .start:
            return "play.fill"
        case .stop:
            return "stop.fill"
        case .restart:
            return "arrow.clockwise"
        case .kill:
            return "bolt.fill"
        }
    }

    /// 会打断在线玩家，删除或关闭类操作在系统里统一用红色并二次确认。
    var isDestructive: Bool {
        self == .stop || self == .kill
    }

    /// 需要二次确认的操作：`stop` 会断开在线玩家，`kill` 还可能丢存档。
    var requiresConfirmation: Bool {
        isDestructive
    }

    /// 请求发出后立即展示的过渡状态，避免界面停留在旧状态。
    var transitionalStatus: String {
        switch self {
        case .start:
            return "starting"
        case .restart:
            return "restarting"
        case .stop, .kill:
            return "stopping"
        }
    }
}
