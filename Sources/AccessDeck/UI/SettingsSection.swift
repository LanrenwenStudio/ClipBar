import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: Content

    init(title: String, subtitle: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(title)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AccessDeckTheme.cardRadius)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AccessDeckTheme.cardRadius)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}
