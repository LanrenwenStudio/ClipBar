import SwiftUI

struct AccessDeckFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 11.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AccessDeckTheme.controlRadius)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AccessDeckTheme.controlRadius)
                    .strokeBorder(
                        isFocused ? Color.blue.opacity(0.5) : Color.primary.opacity(0.07),
                        lineWidth: isFocused ? 1 : 0.5
                    )
            )
    }
}
