import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private enum CommentThreadLayout {
    #if os(macOS)
    static let avatarSize: CGFloat = 20
    static let headerHeight: CGFloat = 22
    static let verticalPadding: CGFloat = 10
    static let contentSpacing: CGFloat = 8
    static let childIndent: CGFloat = 24
    static let bodyFontSize: CGFloat = 13
    static let bodyLineSpacing: CGFloat = 3
    static let headerFontSize: CGFloat = 11
    static let metadataFontSize: CGFloat = 10
    static let actionFontSize: CGFloat = 10
    static let touchTarget: CGFloat = 22
    #else
    static let avatarSize: CGFloat = 22
    static let headerHeight: CGFloat = 36
    static let verticalPadding: CGFloat = 10
    static let contentSpacing: CGFloat = 10
    static let childIndent: CGFloat = 20
    static let bodyFontSize: CGFloat = 16
    static let bodyLineSpacing: CGFloat = 5
    static let headerFontSize: CGFloat = 13
    static let metadataFontSize: CGFloat = 12
    static let actionFontSize: CGFloat = 13
    static let touchTarget: CGFloat = 32
    #endif

    static let maximumIndentDepth = 5
    static let lineWidth: CGFloat = 1

    static var bodyIndent: CGFloat {
        childIndent + 4
    }

    static var spineX: CGFloat {
        avatarSize / 2
    }

    static var childAvatarCenterY: CGFloat {
        verticalPadding + headerHeight / 2
    }

    static func lineColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.27, green: 0.28, blue: 0.30)
            : Color(red: 0.79, green: 0.80, blue: 0.82)
    }
}

struct CommentView: View {
    let item: Item
    let storyAuthor: String?
    let depth: Int
    let parentAuthor: String?
    let collapseAll: Bool

    private let previewThreads: [Int: [Item]]?
    private let expandPreview: Bool

    @Environment(\.colorScheme) private var colorScheme

    @State private var model: CommentRepliesModel
    @State private var isCollapsed: Bool
    @State private var repliesExpanded: Bool
    @State private var showFullText = false

    init(
        item: Item,
        storyAuthor: String? = nil,
        depth: Int = 0,
        parentAuthor: String? = nil,
        collapseAll: Bool = false,
        previewThreads: [Int: [Item]]? = nil,
        expandPreview: Bool = false
    ) {
        self.item = item
        self.storyAuthor = storyAuthor
        self.depth = depth
        self.parentAuthor = parentAuthor
        self.collapseAll = collapseAll
        self.previewThreads = previewThreads
        self.expandPreview = expandPreview

        _model = State(
            initialValue: CommentRepliesModel(
                item: item,
                previewReplies: previewThreads?[item.id]
            )
        )
        _isCollapsed = State(initialValue: collapseAll)
        _repliesExpanded = State(initialValue: expandPreview)
    }

    private var author: String {
        item.by ?? "Deleted user"
    }

    private var replyCount: Int {
        model.visibleReplyCountEstimate
    }

    private var replyLabel: String {
        "\(replyCount) \(replyCount == 1 ? "reply" : "replies")"
    }

    private var canExpandText: Bool {
        (item.text?.count ?? 0) > 800
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CommentThreadLayout.contentSpacing) {
            VStack(alignment: .leading, spacing: CommentThreadLayout.contentSpacing) {
                header

                if !isCollapsed {
                    commentBody
                        .padding(.leading, CommentThreadLayout.bodyIndent)

                    actions
                        .padding(.leading, CommentThreadLayout.bodyIndent)
                }
            }
            .overlay(alignment: .leading) {
                if !isCollapsed && repliesExpanded && replyCount > 0 && depth < CommentThreadLayout.maximumIndentDepth {
                    ThreadStem()
                        .stroke(
                            CommentThreadLayout.lineColor(for: colorScheme),
                            style: StrokeStyle(lineWidth: CommentThreadLayout.lineWidth, lineCap: .butt)
                        )
                        .padding(.bottom, -CommentThreadLayout.contentSpacing)
                        .frame(width: CommentThreadLayout.childIndent)
                        .allowsHitTesting(false)
                }
            }

            if !isCollapsed && repliesExpanded && replyCount > 0 {
                replyThread
            }
        }
        .padding(.vertical, CommentThreadLayout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: collapseAll) { _, collapsed in
            isCollapsed = collapsed
        }
        .contextMenu {
            Link("Open Comment on Hacker News", destination: item.discussionURL)

            Button("Copy Comment Link", systemImage: "link") {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.discussionURL.absoluteString, forType: .string)
                #else
                UIPasteboard.general.url = item.discussionURL
                #endif
            }

            Button(isCollapsed ? "Expand Comment" : "Collapse Comment") {
                isCollapsed.toggle()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            CommentAvatar(author: author)

            Text(author)
                .font(.system(size: CommentThreadLayout.headerFontSize, weight: .semibold))
                .lineLimit(1)

            if item.by != nil && item.by == storyAuthor {
                Text("OP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Original poster")
            }

            if let time = item.timeStringRepresentation {
                Text("· \(time)")
                    .font(.system(size: CommentThreadLayout.metadataFontSize))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            Button {
                isCollapsed.toggle()
            } label: {
                Image(systemName: isCollapsed ? "plus" : "minus")
                    .font(.system(size: CommentThreadLayout.metadataFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: CommentThreadLayout.touchTarget,
                        height: CommentThreadLayout.touchTarget
                    )
                    .contentShape(Rectangle())
            }
            .clickableCursor()
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand comment" : "Collapse comment and replies")
            .accessibilityLabel(isCollapsed ? "Expand comment" : "Collapse comment and replies")
        }
        .frame(height: CommentThreadLayout.headerHeight)
    }

    @ViewBuilder
    private var commentBody: some View {
        if depth > CommentThreadLayout.maximumIndentDepth, let parentAuthor {
            Text("Replying to \(parentAuthor)")
                .font(.system(size: CommentThreadLayout.metadataFontSize))
                .foregroundStyle(.secondary)
        }

        if let text = item.text {
            HTMLText(
                text: text,
                fontSize: CommentThreadLayout.bodyFontSize,
                lineSpacing: CommentThreadLayout.bodyLineSpacing
            )
                .lineLimit(canExpandText && !showFullText ? 8 : nil)

            if canExpandText {
                Button(showFullText ? "Show less" : "Read more") {
                    showFullText.toggle()
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .font(.system(size: CommentThreadLayout.actionFontSize, weight: .semibold))
                .foregroundStyle(.orange)
                #if os(iOS)
                .frame(minHeight: CommentThreadLayout.touchTarget)
                .contentShape(Rectangle())
                #endif
            }
        }
    }

    private var actions: some View {
        #if os(macOS)
        HStack(spacing: 16) {
            if replyCount > 0 {
                Button {
                    repliesExpanded.toggle()
                } label: {
                    Label(
                        repliesExpanded ? "Hide replies" : replyLabel,
                        systemImage: repliesExpanded ? "chevron.up" : "bubble.left"
                    )
                }
                .clickableCursor()
                .foregroundStyle(.orange)
            }

            Link(destination: item.discussionURL) {
                Label("Reply on HN", systemImage: "arrowshape.turn.up.left")
            }
            .clickableCursor()
            .help("Open this comment on Hacker News to reply")

            ShareLink(item: item.discussionURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .clickableCursor()

            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        #else
        HStack(spacing: 8) {
            if replyCount > 0 {
                Button {
                    repliesExpanded.toggle()
                } label: {
                    Label(
                        repliesExpanded ? "Hide replies" : replyLabel,
                        systemImage: repliesExpanded ? "chevron.up" : "bubble.left"
                    )
                    .frame(minHeight: CommentThreadLayout.touchTarget)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.orange)
                .accessibilityHint(repliesExpanded ? "Collapses this comment thread" : "Expands this comment thread")
            }

            Link(destination: item.discussionURL) {
                Image(systemName: "arrowshape.turn.up.left")
                    .frame(width: CommentThreadLayout.touchTarget, height: CommentThreadLayout.touchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Reply on Hacker News")

            ShareLink(item: item.discussionURL) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: CommentThreadLayout.touchTarget, height: CommentThreadLayout.touchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share comment")

            Spacer(minLength: 0)
        }
        .font(.system(size: CommentThreadLayout.actionFontSize, weight: .semibold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        #endif
    }

    private var replyThread: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.replies.enumerated()), id: \.element.id) { index, reply in
                CommentView(
                    item: reply,
                    storyAuthor: storyAuthor,
                    depth: depth + 1,
                    parentAuthor: author,
                    collapseAll: collapseAll,
                    previewThreads: previewThreads,
                    expandPreview: expandPreview
                )
                .padding(.leading, depth < CommentThreadLayout.maximumIndentDepth ? CommentThreadLayout.childIndent : 0)
                .overlay(alignment: .leading) {
                    if depth < CommentThreadLayout.maximumIndentDepth {
                        ThreadBranch(isLast: index == model.replies.count - 1 && !model.hasMore)
                            .stroke(
                                CommentThreadLayout.lineColor(for: colorScheme),
                                style: StrokeStyle(
                                    lineWidth: CommentThreadLayout.lineWidth,
                                    lineCap: .butt,
                                    lineJoin: .round
                                )
                            )
                            .frame(width: CommentThreadLayout.childIndent)
                            .allowsHitTesting(false)
                    }
                }
            }

            if model.isLoading {
                ProgressView("Loading replies…")
                    .font(.system(size: CommentThreadLayout.metadataFontSize))
                    .controlSize(.small)
                    .padding(.leading, CommentThreadLayout.bodyIndent)
                    .padding(.vertical, 12)
            } else if let error = model.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Retry Replies") {
                        Task {
                            await model.loadNextPage()
                        }
                    }
                    .clickableCursor()
                    .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                    .buttonStyle(.plain)
                    .frame(minHeight: CommentThreadLayout.touchTarget)
                }
                .padding(.leading, CommentThreadLayout.bodyIndent)
                .padding(.vertical, 10)
            } else if model.hasMore && model.hasLoaded {
                Button {
                    Task {
                        await model.loadNextPage()
                    }
                } label: {
                    Label("More replies", systemImage: "arrow.turn.down.right")
                        .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .padding(.leading, CommentThreadLayout.bodyIndent)
                .frame(minHeight: CommentThreadLayout.touchTarget)
            } else if model.hasMore {
                Button("Load replies") {
                    Task {
                        await model.loadNextPage()
                    }
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.leading, CommentThreadLayout.bodyIndent)
                .frame(minHeight: CommentThreadLayout.touchTarget)
            }
        }
        .task {
            if !model.hasLoaded {
                await model.loadNextPage()
            }
        }
    }
}

/// The vertical spine starts directly below the parent's avatar. Each child has
/// a quarter-circle elbow ending at its avatar; the last child's spine stops there.
private struct ThreadStem: Shape {
    func path(in rect: CGRect) -> Path {
        let startY = CommentThreadLayout.headerHeight / 2
            + CommentThreadLayout.avatarSize / 2
            + 3

        var path = Path()
        path.move(to: CGPoint(x: CommentThreadLayout.spineX, y: startY))
        path.addLine(to: CGPoint(x: CommentThreadLayout.spineX, y: max(startY, rect.height)))

        return path
    }
}

struct ThreadBranch: Shape {
    let isLast: Bool

    func path(in rect: CGRect) -> Path {
        let spine = CommentThreadLayout.spineX
        let elbowY = min(CommentThreadLayout.childAvatarCenterY, rect.height)
        let radius: CGFloat = min(8, elbowY)
        var path = Path()

        path.move(to: CGPoint(x: spine, y: 0))
        path.addLine(to: CGPoint(x: spine, y: isLast ? elbowY - radius : rect.height))

        path.move(to: CGPoint(x: spine, y: elbowY - radius))
        path.addQuadCurve(
            to: CGPoint(x: spine + radius, y: elbowY),
            control: CGPoint(x: spine, y: elbowY)
        )
        path.addLine(to: CGPoint(x: rect.width - 2, y: elbowY))

        return path
    }
}

private struct CommentAvatar: View {
    let author: String

    private var color: Color {
        let hue = author.utf8.reduce(0) { ($0 * 31 + Int($1)) % 360 }

        return Color(hue: Double(hue) / 360, saturation: 0.45, brightness: 0.8)
    }

    var body: some View {
        Text(String(author.prefix(1)).uppercased())
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: CommentThreadLayout.avatarSize, height: CommentThreadLayout.avatarSize)
            .background(color.opacity(0.13), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
struct CommentsPreview: View {
    @State private var collapsed: Bool

    private let comments: [Item]
    private let threads: [Int: [Item]]

    init(collapsed: Bool = false) {
        _collapsed = State(initialValue: collapsed)

        comments = PreviewData.comments
        threads = PreviewData.threads
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discussion")
                    .font(.system(size: 15, weight: .semibold))

                Text("6 comments")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(collapsed ? "Expand threads" : "Collapse threads") {
                    collapsed.toggle()
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(comments.filter { $0.parent == nil }) { comment in
                    CommentView(
                        item: comment,
                        storyAuthor: "alex",
                        collapseAll: collapsed,
                        previewThreads: threads,
                        expandPreview: true
                    )

                    Divider()
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(PlatformColors.textBackground)
        .tint(.orange)
    }
}

#Preview("Comment threads · Dark", traits: .fixedLayout(width: 640, height: 780)) {
    ScrollView {
        CommentsPreview()
    }
    .preferredColorScheme(.dark)
}

#Preview("Comment threads · Light", traits: .fixedLayout(width: 640, height: 780)) {
    ScrollView {
        CommentsPreview()
    }
    .preferredColorScheme(.light)
}

#Preview("Comment threads · Deep replies", traits: .fixedLayout(width: 640, height: 800)) {
    ScrollView {
        if let root = PreviewData.deepComments.first {
            CommentView(
                item: root,
                storyAuthor: root.by,
                previewThreads: PreviewData.deepThreads,
                expandPreview: true
            )
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
    .tint(.orange)
}

#Preview("Comment threads · Collapsed", traits: .fixedLayout(width: 640, height: 240)) {
    CommentsPreview(collapsed: true)
        .preferredColorScheme(.dark)
}
#endif
