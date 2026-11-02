import SwiftUI
import XCTest
@testable import HNReader

final class SplitColumnWidthTests: XCTestCase {
    @MainActor
    func testStoryColumnResistsDividerDraggingAndWindowResizing() async throws {
        let suite = "HNReaderTests.SplitWidth.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let state = AppState(defaults: defaults)
        state.sidebarSelection = .saved

        let host = NSHostingController(rootView: HomeView()
            .environmentObject(state)
            .frame(minWidth: 1440, minHeight: 600))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1600, height: 800),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = host

        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(200))

        let (controller, pane) = try XCTUnwrap(Self.storyPane(in: host.view))
        let split = controller.splitView
        let index = try XCTUnwrap(controller.splitViewItems.firstIndex { $0 === pane })

        XCTAssertEqual(
            pane.minimumThickness - pane.viewController.view.safeAreaInsets.left,
            520,
            accuracy: 0.5
        )
        XCTAssertFalse(pane.canCollapse)
        XCTAssertFalse(pane.canCollapseFromWindowResize)
        XCTAssertFalse(controller.splitView(split, canCollapseSubview: pane.viewController.view))
        XCTAssertGreaterThanOrEqual(Self.usableWidth(of: pane), 519.5)

        // Move the right divider far enough left to reproduce the clipped rows.
        let left = pane.viewController.view.frame.minX
        split.setPosition(left + 140, ofDividerAt: index)
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(Self.usableWidth(of: pane), 519.5)

        window.setContentSize(NSSize(width: 1440, height: 700))
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(Self.usableWidth(of: pane), 519.5)
        XCTAssertFalse(pane.isCollapsed)

        let sidebar = try XCTUnwrap(controller.splitViewItems.first { $0.behavior == .sidebar })
        sidebar.isCollapsed = true
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThanOrEqual(Self.usableWidth(of: pane), 519.5)

        sidebar.isCollapsed = false
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThanOrEqual(Self.usableWidth(of: pane), 519.5)
    }

    @MainActor
    private static func usableWidth(of pane: NSSplitViewItem) -> CGFloat {
        let view = pane.viewController.view

        return view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
    }

    @MainActor
    private static func storyPane(in view: NSView) -> (NSSplitViewController, NSSplitViewItem)? {
        if let splitView = view as? NSSplitView,
           let controller = splitView.delegate as? NSSplitViewController {
            for item in controller.splitViewItems where item.viewController.isViewLoaded {
                if item.viewController.view.constraints.contains(where: {
                    $0.identifier == "HNReader.storyColumn.minimumWidth"
                }) {
                    return (controller, item)
                }
            }
        }

        for child in view.subviews {
            if let match = storyPane(in: child) {
                return match
            }
        }

        return nil
    }
}
