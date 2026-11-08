//
//  Instance.swift
//  simpfun
//

import Foundation

struct Instance: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String?
    let cpu: Int
    let ram: Int
    let disk: Int

    /// 服务端可能返回 JSON null，此时视为未命名。
    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "未命名实例"
        }
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case cpu
        case ram
        case disk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        cpu = try container.decodeFlexibleInt(forKey: .cpu)
        ram = try container.decodeFlexibleInt(forKey: .ram)
        disk = try container.decodeFlexibleInt(forKey: .disk)
    }
}

private extension KeyedDecodingContainer {
    /// 接口中的数值字段目前以字符串返回，兼容数字类型以免服务端调整后解析失败。
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let string = try? decode(String.self, forKey: key), let value = Int(string) {
            return value
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected Int or a numeric string."
        )
    }
}
