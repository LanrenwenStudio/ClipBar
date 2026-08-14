import SwiftUI

struct ClipBarFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ClipBarTheme.inputBackground, in: RoundedRectangle(cornerRadius: ClipBarTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ClipBarTheme.controlRadius)
                    .strokeBorder(
                        isFocused ? ClipBarTheme.accent : ClipBarTheme.hairline,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
    }
}
