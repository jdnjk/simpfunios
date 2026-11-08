//
//  HistoryRow.swift
//  simpfun
//

import SwiftUI

struct HistoryRow: View {
    let comment: String
    let change: Int
    let balance: Int
    let createTime: Date?

    private var changeText: String {
        change > 0 ? "+\(change)" : String(change)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(comment)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    if let createTime {
                        Text(createTime, format: .dateTime.year().month().day().hour().minute())
                    }
                    Text(verbatim: "余额 \(balance)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(verbatim: changeText)
                .font(.headline)
                .foregroundStyle(change >= 0 ? Color.green : Color.red)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
