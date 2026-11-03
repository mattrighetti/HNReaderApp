import SwiftUI

/// Enforce the usable story-column width on AppKit's native split item.
/// SwiftUI's width preference alone can allow the divider to clip its content.
struct SplitColumnWidth: NSViewRepresentable {
    let minimum: CGFloat
    let maximum: CGFloat

    func makeNSView(context: Context) -> ColumnWidthProbe {
        let view = ColumnWidthProbe()
        view.minimum = minimum
        view.maximum = maximum

        return view
    }

    func updateNSView(_ view: ColumnWidthProbe, context: Context) {
        view.minimum = minimum
        view.maximum = maximum
        view.scheduleUpdate()
    }
}

final class ColumnWidthProbe: NSView {
    var minimum: CGFloat = 312
    var maximum: CGFloat = 720

    private var updateScheduled = false
    private var widthConstraint: NSLayoutConstraint?
    private weak var constrainedView: NSView?
    private weak var observedSplitView: NSSplitView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            NotificationCenter.default.removeObserver(self)
            observedSplitView = nil
        } else {
            scheduleUpdate()
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleUpdate()
    }

    func scheduleUpdate() {
        guard !updateScheduled else {
            return
        }

        updateScheduled = true

        // Wait for SwiftUI to finish attaching its hosting controllers.
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.updateScheduled = false
            self.applyWidth()
        }
    }

    @objc
    private func splitViewDidResize(_ notification: Notification) {
        scheduleUpdate()
    }

    private func applyWidth() {
        guard window != nil, let (controller, item) = enclosingSplitItem() else {
            return
        }

        if observedSplitView !== controller.splitView {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(splitViewDidResize(_:)),
                name: NSSplitView.didResizeSubviewsNotification,
                object: controller.splitView
            )
            observedSplitView = controller.splitView
        }

        let pane = item.viewController.view

        // AppKit can place the sidebar over the content pane. Its safe-area
        // width must be added so the story list itself still gets its minimum usable width.
        let coveredWidth = pane.safeAreaInsets.left + pane.safeAreaInsets.right
        let paneMinimum = minimum + coveredWidth
        let paneMaximum = maximum + coveredWidth
        var changed = false

        if item.maximumThickness != paneMaximum {
            item.maximumThickness = paneMaximum
            changed = true
        }

        if item.minimumThickness != paneMinimum {
            item.minimumThickness = paneMinimum
            changed = true
        }

        if item.canCollapse || item.canCollapseFromWindowResize {
            item.canCollapse = false
            item.canCollapseFromWindowResize = false
            changed = true
        }

        if constrainedView !== pane {
            widthConstraint?.isActive = false

            let constraint = pane.widthAnchor.constraint(greaterThanOrEqualToConstant: paneMinimum)
            constraint.identifier = "HNReader.storyColumn.minimumWidth"
            constraint.isActive = true

            widthConstraint = constraint
            constrainedView = pane
            changed = true
        } else if widthConstraint?.constant != paneMinimum {
            widthConstraint?.constant = paneMinimum
            changed = true
        }

        if changed {
            controller.view.needsLayout = true
        }
    }

    private func enclosingSplitItem() -> (NSSplitViewController, NSSplitViewItem)? {
        var responder: NSResponder? = nextResponder

        while let current = responder {
            if let controller = current as? NSSplitViewController,
               let item = containingItem(in: controller) {
                return (controller, item)
            }

            responder = current.nextResponder
        }

        if let view = window?.contentView {
            return searchSplitViews(in: view)
        }

        return nil
    }

    private func containingItem(in controller: NSSplitViewController) -> NSSplitViewItem? {
        controller.splitViewItems.first { item in
            item.viewController.isViewLoaded && isDescendant(of: item.viewController.view)
        }
    }

    private func searchSplitViews(in view: NSView) -> (NSSplitViewController, NSSplitViewItem)? {
        if let split = view as? NSSplitView,
           let controller = split.delegate as? NSSplitViewController,
           let item = containingItem(in: controller) {
            return (controller, item)
        }

        for child in view.subviews {
            if let match = searchSplitViews(in: child) {
                return match
            }
        }

        return nil
    }
}
