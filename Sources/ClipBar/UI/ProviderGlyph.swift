import SwiftUI

struct ProviderGlyph: View {
    let provider: QuotaProvider
    var size: CGFloat = 13
    var tint: Color? = nil

    var body: some View {
        Group {
            if let image = ProviderIcon.image(for: provider, size: size) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "server.rack")
                    .font(.system(size: max(9, size - 2), weight: .medium))
            }
        }
        .foregroundStyle(tint ?? ClipBarTheme.brandColor(for: provider))
        .accessibilityHidden(true)
    }
}
