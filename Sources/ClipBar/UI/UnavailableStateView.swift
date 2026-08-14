import SwiftUI

struct UnavailableStateView: View {
    let title: String
    let detail: String
    let systemImage: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(detail)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(ClipBarTheme.spacingL)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .center)
    }
}
