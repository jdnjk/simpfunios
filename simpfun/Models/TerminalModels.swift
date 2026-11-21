//
//  TerminalModels.swift
//  simpfun
//

import Foundation

struct TerminalConnection: Decodable, Hashable {
    let token: String
    let socket: String

    var socketURL: URL? {
        URL(string: socket)
    }
}

struct TerminalSocketEvent: Decodable {
    let event: String
    let args: [String]?
}

struct TerminalStats: Decodable, Hashable {
    let cpuAbsolute: Double
    let diskBytes: Int
    let memoryBytes: Int
    let memoryLimitBytes: Int
    let networkRxBytes: Int
    let networkTxBytes: Int
    let state: String
    let uptime: Double

    private enum CodingKeys: String, CodingKey {
        case state
        case uptime
        case network
        case cpuAbsolute = "cpu_absolute"
        case diskBytes = "disk_bytes"
        case memoryBytes = "memory_bytes"
        case memoryLimitBytes = "memory_limit_bytes"
    }

    private struct Network: Decodable {
        let rxBytes: Int
        let txBytes: Int

        private enum CodingKeys: String, CodingKey {
            case rxBytes = "rx_bytes"
            case txBytes = "tx_bytes"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rxBytes = try container.decodeIfPresent(Int.self, forKey: .rxBytes) ?? 0
            txBytes = try container.decodeIfPresent(Int.self, forKey: .txBytes) ?? 0
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cpuAbsolute = try container.decodeIfPresent(Double.self, forKey: .cpuAbsolute) ?? 0
        diskBytes = try container.decodeIfPresent(Int.self, forKey: .diskBytes) ?? 0
        memoryBytes = try container.decodeIfPresent(Int.self, forKey: .memoryBytes) ?? 0
        memoryLimitBytes = try container.decodeIfPresent(Int.self, forKey: .memoryLimitBytes) ?? 0
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        uptime = try container.decodeIfPresent(Double.self, forKey: .uptime) ?? 0

        let network = try container.decodeIfPresent(Network.self, forKey: .network)
        networkRxBytes = network?.rxBytes ?? 0
        networkTxBytes = network?.txBytes ?? 0
    }
}
