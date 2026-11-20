import ViewerCore
import SwiftUI

/// The header chip that marks a development build. Shown only when the running
/// build is not the release channel.
struct DevChannelBadge: View {
    var body: some View {
        Text(BuildChannel.labelText)
            .font(BPTokens.Typography.caption.weight(.heavy))
            .foregroundStyle(Color.white)
            .padding(.horizontal, BPTokens.Spacing.xs)
            .padding(.vertical, BPTokens.Spacing.xxs)
            .background(Capsule().fill(Color.orange))
            .fixedSize()
            .help("Development build")
            .accessibilityLabel("Development build")
    }
}
