import SwiftUI

struct MenuBarStatusLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: ClipBarTheme.spacingXS) {
            if model.statusSegments.isEmpty {
                Text(model.statusTitle)
                    .monospacedDigit()
            } else {
                ForEach(Array(model.statusSegments.enumerated()), id: \.element.id) { index, segment in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 1, height: 11)
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: 3) {
                        if let image = ProviderIcon.image(for: segment.provider, size: 13) {
                            Image(nsImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 13, height: 13)
                        }
                        Text(segment.percentText)
                            .monospacedDigit()
                    }
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 2)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.statusAccessibilityLabel)
    }
}
