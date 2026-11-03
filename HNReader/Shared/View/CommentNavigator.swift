import SwiftUI

struct CommentPositions: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// Only top-level comment frames participate; nested replies are skipped.
struct CommentNavigation {
    enum Direction {
        case previous
        case next
    }

    let ids: [Int]
    let frames: [Int: CGRect]
    var viewportHeight: CGFloat? = nil

    private let topTolerance: CGFloat = 8

    private var currentIndex: Int? {
        let aboveTop = ids.lastIndex { id in
            guard let frame = frames[id] else {
                return false
            }

            return frame.minY <= topTolerance
        }

        // A short final thread cannot always reach the top of the viewport.
        // Treat it as the end once it is fully visible below an earlier thread.
        if
            aboveTop != nil,
            let viewportHeight,
            let last = ids.last,
            let frame = frames[last],
            frame.minY >= 0,
            frame.maxY <= viewportHeight
        {
            return ids.count - 1
        }

        if let aboveTop {
            return aboveTop
        }

        // LazyVStack can release the preceding row between comment headers.
        if let nextVisible = ids.firstIndex(where: { frames[$0] != nil }), nextVisible > 0 {
            return nextVisible - 1
        }

        return nil
    }

    func target(for direction: Direction) -> Int? {
        switch direction {
        case .previous:
            guard let currentIndex else {
                return nil
            }

            let id = ids[currentIndex]

            // When reading a thread's replies, go back to its own header first.
            if (frames[id]?.minY ?? -.infinity) < -topTolerance {
                return id
            }

            return currentIndex > 0 ? ids[currentIndex - 1] : nil

        case .next:
            let index = (currentIndex ?? -1) + 1

            return index < ids.count ? ids[index] : nil
        }
    }
}

struct CommentJumpControls: View {
    let canGoUp: Bool
    let canGoDown: Bool
    let isLoading: Bool
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: previous) {
                Image(systemName: "arrow.up")
                    .frame(width: 38, height: 34)
                    .contentShape(Rectangle())
            }
            .clickableCursor()
            .disabled(!canGoUp || isLoading)
            .help("Previous top-level comment")
            .accessibilityLabel("Previous top-level comment")

            Rectangle()
                .fill(PlatformColors.separator)
                .frame(width: 1, height: 16)

            Button(action: next) {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.down")
                    }
                }
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
            }
            .clickableCursor()
            .disabled(!canGoDown || isLoading)
            .help("Next top-level comment")
            .accessibilityLabel("Next top-level comment")
        }
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.plain)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(PlatformColors.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigate comment threads")
    }
}

#Preview("Comment navigation") {
    CommentJumpControls(
        canGoUp: true,
        canGoDown: true,
        isLoading: false,
        previous: {},
        next: {}
    )
    .padding(24)
}
