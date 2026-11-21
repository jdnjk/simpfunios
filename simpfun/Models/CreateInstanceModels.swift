//
//  CreateInstanceModels.swift
//  simpfun
//

import Foundation

enum MirrorType: String, Hashable {
    case official
    case thirdParty

    var title: String {
        switch self {
        case .official:
            return "官方镜像"
        case .thirdParty:
            return "第三方镜像"
        }
    }

    var subtitle: String {
        switch self {
        case .official:
            return "纯净基础镜像"
        case .thirdParty:
            return "整合包 以及 更多镜像"
        }
    }

    var systemImage: String {
        switch self {
        case .official:
            return "shippingbox.fill"
        case .thirdParty:
            return "puzzlepiece.extension.fill"
        }
    }

    var isCustom: Bool {
        self == .thirdParty
    }
}

struct Game: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let picPath: String?
    let priority: Int

    var imageURL: URL? {
        picPath.flatMap(URL.init(string:))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case priority
        case picPath = "pic_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        picPath = try container.decodeIfPresent(String.self, forKey: .picPath)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    }
}

struct GameKind: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let picPath: String?
    let link: String?
    let isWindows: Bool?
    let like: Int?
    let dislike: Int?

    var imageURL: URL? {
        picPath.flatMap(URL.init(string:))
    }

    var linkURL: URL? {
        link.flatMap(URL.init(string:))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case link
        case like
        case dislike
        case picPath = "pic_path"
        case isWindows = "is_windows"
    }
}

struct GameVersion: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let recommendSetting: String?
    let like: Int?
    let dislike: Int?
    let size: String?

    var formattedSize: String? {
        guard let size, let bytes = Int64(size) else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case like
        case dislike
        case size
        case recommendSetting = "recommend_setting"
    }
}

struct ShopItem: Decodable, Hashable, Identifiable {
    let id: Int
    let cpu: Int
    let ram: Int
    let disk: Int
    let traffic: Int
    let point: Int
    let spec: String
    let areaGrade: String
    let areaVendor: String
    let areaIsWindows: Bool
    let description: String?
    let creatable: Bool

    /// 例如 B+.I.L.L，最后一位为 L（Linux）或 W（Windows）。
    var displayCode: String {
        "\(areaGrade).\(areaVendor).\(spec).\(areaIsWindows ? "W" : "L")"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cpu
        case ram
        case disk
        case traffic
        case point
        case spec
        case description
        case creatable
        case areaGrade = "area_grade"
        case areaVendor = "area_vendor"
        case areaIsWindows = "area_is_windows"
    }
}

struct InstanceConfirmation: Decodable, Hashable {
    let gameName: String
    let imageName: String
    let versionName: String
    let cpu: Int
    let ram: Int
    let disk: Int
    let grade: String
    let traffic: Int
    let description: String?
    let point: Int

    private enum CodingKeys: String, CodingKey {
        case cpu
        case ram
        case disk
        case grade
        case traffic
        case description
        case point
        case gameName = "game_name"
        case imageName = "image_name"
        case versionName = "version_name"
    }
}
