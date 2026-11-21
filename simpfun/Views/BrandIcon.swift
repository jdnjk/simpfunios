//
//  BrandIcon.swift
//  simpfun
//

import SwiftUI

struct BrandIcon: View {
    var size: CGFloat = 88

    var body: some View {
        Image(systemName: "server.rack")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    BrandIcon()
}
