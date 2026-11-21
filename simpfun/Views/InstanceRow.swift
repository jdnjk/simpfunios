//
//  InstanceRow.swift
//  simpfun
//

import SwiftUI

struct InstanceRow: View {
    let instance: Instance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(instance.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(verbatim: "ID \(instance.id)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                Label {
                    Text(verbatim: "\(instance.cpu) 核")
                } icon: {
                    Image(systemName: "cpu")
                }

                Label {
                    Text(verbatim: "\(instance.ram) GB")
                } icon: {
                    Image(systemName: "memorychip")
                }

                Label {
                    Text(verbatim: "\(instance.disk) GB")
                } icon: {
                    Image(systemName: "internaldrive")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(instance.displayName)，ID \(instance.id)，\(instance.cpu) 核，内存 \(instance.ram) GB，储存 \(instance.disk) GB"
        )
    }
}
