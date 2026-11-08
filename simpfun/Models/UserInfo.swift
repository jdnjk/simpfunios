//
//  UserInfo.swift
//  simpfun
//

import Foundation

struct UserInfo: Decodable, Equatable {
    let id: Int
    let username: String
    let point: Int
    let diamond: Int
    let verified: Bool
    let isDev: Bool
    let createTime: Date
    let qq: Int?
    let isPro: Bool
    let proValid: Bool
    let announcement: Announcement

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case point
        case diamond
        case verified
        case qq
        case announcement
        case isDev = "is_dev"
        case createTime = "create_time"
        case isPro = "is_pro"
        case proValid = "pro_valid"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        point = try container.decode(Int.self, forKey: .point)
        diamond = try container.decode(Int.self, forKey: .diamond)
        verified = try container.decode(Bool.self, forKey: .verified)
        isDev = try container.decode(Bool.self, forKey: .isDev)
        createTime = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .createTime))
        qq = try container.decodeIfPresent(Int.self, forKey: .qq)
        isPro = try container.decode(Bool.self, forKey: .isPro)
        proValid = try container.decode(Bool.self, forKey: .proValid)
        announcement = try container.decodeIfPresent(Announcement.self, forKey: .announcement) ?? .hidden
    }
}
