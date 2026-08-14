import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClipBarTheme.spacingM) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(ClipBarTheme.spacingL)
        .background(ClipBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: ClipBarTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ClipBarTheme.cardRadius)
                .strokeBorder(ClipBarTheme.hairline, lineWidth: 1)
        }
    }
}
