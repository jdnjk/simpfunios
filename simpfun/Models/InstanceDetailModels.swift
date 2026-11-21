//
//  InstanceDetailModels.swift
//  simpfun
//

import Foundation

struct InstanceDetail: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let isPro: Bool
    let status: String
    let isSuspended: Bool
    let utilization: InstanceUtilization?
    let gameInfo: InstanceGameInfo?
    let createTime: Date?
    let lastPaidTime: Date?
    let cpu: Int
    let disk: Int
    let ram: Int
    let point: Int
    let areaGrade: String
    let defaultAllocation: InstanceAllocation?
    let allocations: [InstanceAllocation]
    let state: Int
    let haveTask: Bool
    let uuid: String
    let devMode: Bool
    let shortage: Bool
    let diamond: InstanceDiamond?
    let traffic: InstanceTraffic?

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "未命名实例"
        }
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case cpu
        case disk
        case ram
        case point
        case state
        case uuid
        case allocations
        case utilization
        case diamond
        case traffic
        case shortage
        case isPro = "is_pro"
        case isSuspended = "is_suspended"
        case gameInfo = "game_info"
        case createTime = "create_time"
        case lastPaidTime = "last_paid_time"
        case areaGrade = "area_grade"
        case defaultAllocation = "default_allocation"
        case haveTask = "have_task"
        case devMode = "dev_mode"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        isSuspended = try container.decodeIfPresent(Bool.self, forKey: .isSuspended) ?? false
        utilization = try container.decodeIfPresent(InstanceUtilization.self, forKey: .utilization)
        gameInfo = try container.decodeIfPresent(InstanceGameInfo.self, forKey: .gameInfo)
        createTime = Self.decodeDate(container, forKey: .createTime)
        lastPaidTime = Self.decodeDate(container, forKey: .lastPaidTime)
        cpu = try container.decodeIfPresent(Int.self, forKey: .cpu) ?? 0
        disk = try container.decodeIfPresent(Int.self, forKey: .disk) ?? 0
        ram = try container.decodeIfPresent(Int.self, forKey: .ram) ?? 0
        point = try container.decodeIfPresent(Int.self, forKey: .point) ?? 0
        areaGrade = try container.decodeIfPresent(String.self, forKey: .areaGrade) ?? ""
        defaultAllocation = try container.decodeIfPresent(InstanceAllocation.self, forKey: .defaultAllocation)
        allocations = try container.decodeIfPresent([InstanceAllocation].self, forKey: .allocations) ?? []
        state = try container.decodeIfPresent(Int.self, forKey: .state) ?? 0
        haveTask = try container.decodeIfPresent(Bool.self, forKey: .haveTask) ?? false
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        devMode = try container.decodeIfPresent(Bool.self, forKey: .devMode) ?? false
        shortage = try container.decodeIfPresent(Bool.self, forKey: .shortage) ?? false
        diamond = try container.decodeIfPresent(InstanceDiamond.self, forKey: .diamond)
        traffic = try container.decodeIfPresent(InstanceTraffic.self, forKey: .traffic)
    }

    private static func decodeDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Date? {
        guard let raw = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        return ISO8601Date.parse(raw)
    }
}

struct InstanceUtilization: Decodable, Hashable {
    let memoryBytes: Int
    let cpuAbsolute: Double
    let diskBytes: Int
    let networkRxBytes: Int
    let networkTxBytes: Int
    let uptime: Double
    let diskLastCheckTime: Date?

    private enum CodingKeys: String, CodingKey {
        case memoryBytes = "memory_bytes"
        case cpuAbsolute = "cpu_absolute"
        case diskBytes = "disk_bytes"
        case networkRxBytes = "network_rx_bytes"
        case networkTxBytes = "network_tx_bytes"
        case uptime
        case diskLastCheckTime = "disk_last_check_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memoryBytes = try container.decodeIfPresent(Int.self, forKey: .memoryBytes) ?? 0
        cpuAbsolute = try container.decodeIfPresent(Double.self, forKey: .cpuAbsolute) ?? 0
        diskBytes = try container.decodeIfPresent(Int.self, forKey: .diskBytes) ?? 0
        networkRxBytes = try container.decodeIfPresent(Int.self, forKey: .networkRxBytes) ?? 0
        networkTxBytes = try container.decodeIfPresent(Int.self, forKey: .networkTxBytes) ?? 0
        uptime = try container.decodeIfPresent(Double.self, forKey: .uptime) ?? 0
        if let raw = try container.decodeIfPresent(String.self, forKey: .diskLastCheckTime) {
            diskLastCheckTime = ISO8601Date.parse(raw)
        } else {
            diskLastCheckTime = nil
        }
    }
}

struct InstanceGameInfo: Decodable, Hashable {
    let gameName: String
    let kindName: String
    let versionName: String
    let custom: Bool
    let description: String?
    let link: String?

    var linkURL: URL? {
        link.flatMap(URL.init(string:))
    }

    private enum CodingKeys: String, CodingKey {
        case custom
        case description
        case link
        case gameName = "game_name"
        case kindName = "kind_name"
        case versionName = "version_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameName = try container.decodeIfPresent(String.self, forKey: .gameName) ?? ""
        kindName = try container.decodeIfPresent(String.self, forKey: .kindName) ?? ""
        versionName = try container.decodeIfPresent(String.self, forKey: .versionName) ?? ""
        custom = try container.decodeIfPresent(Bool.self, forKey: .custom) ?? false
        description = try container.decodeIfPresent(String.self, forKey: .description)
        link = try container.decodeIfPresent(String.self, forKey: .link)
    }
}

struct InstanceAllocation: Decodable, Hashable, Identifiable {
    let serverID: Int?
    let ip: String
    let port: Int
    let isDefault: Bool

    var id: String {
        serverID.map(String.init) ?? endpoint
    }

    var endpoint: String {
        "\(ip):\(port)"
    }

    private enum CodingKeys: String, CodingKey {
        case ip
        case port
        case serverID = "id"
        case isDefault = "is_default"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverID = try container.decodeIfPresent(Int.self, forKey: .serverID)
        ip = try container.decodeIfPresent(String.self, forKey: .ip) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 0
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

struct InstanceDiamond: Decodable, Hashable {
    let left: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = try container.decodeIfPresent(Int.self, forKey: .left) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case left
    }
}

struct InstanceTraffic: Decodable, Hashable {
    let plan: Int
    let remainBytes: Int
    let autoReset: Bool

    private enum CodingKeys: String, CodingKey {
        case plan
        case autoReset = "auto_reset"
        case remainBytes = "remain_bytes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plan = try container.decodeIfPresent(Int.self, forKey: .plan) ?? 0
        remainBytes = try container.decodeIfPresent(Int.self, forKey: .remainBytes) ?? 0
        autoReset = try container.decodeIfPresent(Bool.self, forKey: .autoReset) ?? false
    }
}

struct InstanceTask: Decodable, Hashable, Identifiable {
    let id: Int
    let status: Int
    let comment: String
    let createTime: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case comment
        case createTime = "create_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        status = try container.decodeIfPresent(Int.self, forKey: .status) ?? -1
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        if let raw = try container.decodeIfPresent(String.self, forKey: .createTime) {
            createTime = ISO8601Date.parse(raw)
        } else {
            createTime = nil
        }
    }
}

struct InstanceTasks: Hashable {
    let list: [InstanceTask]
    let running: Int
    let waiting: Int
    let numFirstWaiting: Int
    let runningPro: Int
    let waitingPro: Int
    let numFirstWaitingPro: Int
    let isPro: Bool

    var firstWaitingTask: InstanceTask? {
        if numFirstWaiting > 0, let matched = list.first(where: { $0.id == numFirstWaiting }) {
            return matched
        }
        return list.first { $0.status == -1 }
    }
}
