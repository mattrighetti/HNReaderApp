import SwiftUI

extension View {
    func clickableCursor(enabled: Bool = true) -> some View {
        modifier(ClickableCursor(enabled: enabled))
    }
}

private struct ClickableCursor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(enabled && isEnabled ? .link : nil)
        } else {
            content.background {
                CursorRegion(enabled: enabled && isEnabled)
            }
        }
    }
}

/// Cursor rectangles follow scrolling and view removal without a global cursor stack.
private struct CursorRegion: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> CursorView {
        CursorView()
    }

    func updateNSView(_ view: CursorView, context: Context) {
        guard view.enabled != enabled else {
            return
        }

        view.enabled = enabled
        view.window?.invalidateCursorRects(for: view)
    }

    final class CursorView: NSView {
        var enabled = false

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func resetCursorRects() {
            super.resetCursorRects()

            if enabled {
                addCursorRect(visibleRect, cursor: .pointingHand)
            }
        }
    }
}
