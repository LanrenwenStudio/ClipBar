import SwiftUI

struct ProviderGlyph: View {
    let provider: QuotaProvider
    var size: CGFloat = 14
    var tint: Color? = nil

    var body: some View {
        Group {
#if os(macOS)
            if let image = ProviderIcon.image(for: provider, size: size) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "server.rack")
                    .font(.system(size: max(9, size - 2), weight: .medium))
            }
#else
            if let image = ProviderIcon.image(for: provider, size: size) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: ProviderIcon.systemFallbackName(for: provider))
                    .font(.system(size: max(10, size - 1), weight: .semibold))
            }
#endif
        }
        .foregroundStyle(tint ?? ClipBarTheme.brandColor(for: provider))
        .accessibilityHidden(true)
    }
}
