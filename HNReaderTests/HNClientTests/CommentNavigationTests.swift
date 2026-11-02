import SwiftUI
import XCTest
@testable import HNReader

final class CommentNavigationTests: XCTestCase {
    func testBeforeDiscussionStartsAtFirstTopLevelComment() {
        let navigation = CommentNavigation(
            ids: [1, 2, 3],
            frames: [1: frame(y: 300), 2: frame(y: 600)]
        )

        XCTAssertNil(navigation.target(for: .previous))
        XCTAssertEqual(navigation.target(for: .next), 1)
    }

    func testReadingRepliesReturnsToParentHeaderOrSkipsToNextParent() {
        let navigation = CommentNavigation(
            ids: [1, 2, 3],
            frames: [1: frame(y: -400, height: 900), 2: frame(y: 500), 99: frame(y: 0)]
        )

        XCTAssertEqual(navigation.target(for: .previous), 1)
        XCTAssertEqual(navigation.target(for: .next), 2)
    }

    func testAtCommentHeaderMovesToAdjacentTopLevelComments() {
        let navigation = CommentNavigation(
            ids: [1, 2, 3],
            frames: [1: frame(y: -400), 2: frame(y: -2), 3: frame(y: 400)]
        )

        XCTAssertEqual(navigation.target(for: .previous), 1)
        XCTAssertEqual(navigation.target(for: .next), 3)
    }

    func testEmptyAndFinalBoundaries() {
        let empty = CommentNavigation(ids: [], frames: [:])

        XCTAssertNil(empty.target(for: .previous))
        XCTAssertNil(empty.target(for: .next))

        let final = CommentNavigation(ids: [1, 2], frames: [2: frame(y: 0)])

        XCTAssertEqual(final.target(for: .previous), 1)
        XCTAssertNil(final.target(for: .next))
    }

    func testShortFinalThreadDoesNotRemainANextTargetAtBottom() {
        let navigation = CommentNavigation(
            ids: [1, 2, 3],
            frames: [2: frame(y: -300, height: 500), 3: frame(y: 200, height: 150)],
            viewportHeight: 500
        )

        XCTAssertEqual(navigation.target(for: .previous), 2)
        XCTAssertNil(navigation.target(for: .next))
    }

    func testReleasedPreviousRowIsInferredFromNextVisibleHeader() {
        let navigation = CommentNavigation(ids: [1, 2, 3], frames: [3: frame(y: 20)])

        XCTAssertEqual(navigation.target(for: .previous), 2)
        XCTAssertEqual(navigation.target(for: .next), 3)
    }

    @MainActor
    func testNativeScrollJumpsOverLongRepliesAndBackToPreviousParent() async throws {
        let model = NavigationHarnessModel()
        let initial = expectation(description: "First thread laid out")
        let second = expectation(description: "Second thread aligned at top")
        let third = expectation(description: "Third thread aligned at top")
        let back = expectation(description: "Back to second thread")

        var stage = 0
        let observation = model.$frames.sink { frames in
            switch stage {
            case 0 where abs(frames[1]?.minY ?? .infinity) < 8:
                stage = 1
                initial.fulfill()

            case 1 where abs(frames[2]?.minY ?? .infinity) < 8:
                stage = 2
                second.fulfill()

            case 2 where abs(frames[3]?.minY ?? .infinity) < 8:
                stage = 3
                third.fulfill()

            case 3 where abs(frames[2]?.minY ?? .infinity) < 8:
                stage = 4
                back.fulfill()

            default:
                break
            }
        }
        defer { observation.cancel() }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: NavigationHarness(model: model))

        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await fulfillment(of: [initial], timeout: 3)

        model.target = model.navigation.target(for: .next)
        await fulfillment(of: [second], timeout: 3)

        model.target = model.navigation.target(for: .next)
        await fulfillment(of: [third], timeout: 3)

        model.target = model.navigation.target(for: .previous)
        await fulfillment(of: [back], timeout: 3)
    }

    private func frame(y: CGFloat, height: CGFloat = 200) -> CGRect {
        CGRect(x: 0, y: y, width: 500, height: height)
    }
}

@MainActor
private final class NavigationHarnessModel: ObservableObject {
    @Published var frames: [Int: CGRect] = [:]
    @Published var target: Int?

    var navigation: CommentNavigation {
        CommentNavigation(ids: [1, 2, 3], frames: frames, viewportHeight: 500)
    }
}

private struct NavigationHarness: View {
    @ObservedObject var model: NavigationHarnessModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { id in
                        VStack(alignment: .leading) {
                            Text("Top-level comment \(id)")

                            if id == 1 {
                                Text("A nested reply, skipped by navigation")
                                    .padding(.top, 300)
                                    .id(99)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: id == 1 ? 1400 : 600)
                        .id(id)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: CommentPositions.self,
                                    value: [id: geometry.frame(in: .named("testDiscussion"))]
                                )
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "testDiscussion")
            .onPreferenceChange(CommentPositions.self) { frames in
                model.frames = frames
            }
            .onChange(of: model.target) { _, id in
                if let id {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }
}
