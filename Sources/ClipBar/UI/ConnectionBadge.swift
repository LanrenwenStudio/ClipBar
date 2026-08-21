import SwiftUI

struct ConnectionBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(color.opacity(0.12)))
        .foregroundStyle(color)
    }
}
