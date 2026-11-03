import SwiftUI

extension View {
    func clickableCursor(enabled: Bool = true) -> some View {
        modifier(ClickableCursor(enabled: enabled))
    }
}

private struct ClickableCursor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let enabled: Bool

    func body(content: Content) -> some View {
        content.pointerStyle(enabled && isEnabled ? .link : nil)
    }
}
