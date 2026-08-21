import SwiftUI

struct ClipBarFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 11.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        isFocused ? Color.blue.opacity(0.45) : Color.primary.opacity(0.07),
                        lineWidth: isFocused ? 1 : 0.5
                    )
            )
    }
}
