import SwiftUI

struct MenuBarStatusLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            if model.statusSegments.isEmpty {
                Text(model.statusTitle)
                    .monospacedDigit()
            } else {
                ForEach(model.statusSegments) { segment in
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
