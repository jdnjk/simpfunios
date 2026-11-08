//
//  InviteInfo.swift
//  simpfun
//

import Foundation

struct InviteInfo: Decodable, Equatable {
    let registerTimes: Int
    let registerVerifyTimes: Int
    let registerTotalIncome: Int
    let registerTotalIncomeFromPro: Int
    let inviteCode: Int

    var inviteLink: URL? {
        URL(string: "https://simpfun.cn/auth?type=register&code=\(inviteCode)")
    }

    private enum CodingKeys: String, CodingKey {
        case registerTimes = "register_times"
        case registerVerifyTimes = "register_verify_times"
        case registerTotalIncome = "register_total_income"
        case registerTotalIncomeFromPro = "register_total_income_from_pro"
        case inviteCode = "invite_code"
    }
}
