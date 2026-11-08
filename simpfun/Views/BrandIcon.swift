//
//  BrandIcon.swift
//  simpfun
//

import SwiftUI

struct BrandIcon: View {
    var body: some View {
        Image(systemName: "server.rack")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    BrandIcon()
}
