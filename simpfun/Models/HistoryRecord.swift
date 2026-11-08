//
//  HistoryRecord.swift
//  simpfun
//

import Foundation

struct PointRecord: Decodable, Identifiable, Equatable {
    let id: Int
    let point: Int
    let pointLeft: Int
    let createTime: Date?
    let comment: String

    private enum CodingKeys: String, CodingKey {
        case id
        case point
        case comment
        case pointLeft = "point_left"
        case createTime = "create_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        point = try container.decode(Int.self, forKey: .point)
        pointLeft = try container.decode(Int.self, forKey: .pointLeft)
        comment = try container.decode(String.self, forKey: .comment)
        if let rawDate = try container.decodeIfPresent(String.self, forKey: .createTime) {
            createTime = ISO8601Date.parse(rawDate)
        } else {
            createTime = nil
        }
    }
}

struct DiamondRecord: Decodable, Identifiable, Equatable {
    let id: Int
    let diamond: Int
    let diamondLeft: Int
    let createTime: Date?
    let comment: String

    private enum CodingKeys: String, CodingKey {
        case id
        case diamond
        case comment
        case diamondLeft = "diamond_left"
        case createTime = "create_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        diamond = try container.decode(Int.self, forKey: .diamond)
        diamondLeft = try container.decode(Int.self, forKey: .diamondLeft)
        comment = try container.decode(String.self, forKey: .comment)
        if let rawDate = try container.decodeIfPresent(String.self, forKey: .createTime) {
            createTime = ISO8601Date.parse(rawDate)
        } else {
            createTime = nil
        }
    }
}
