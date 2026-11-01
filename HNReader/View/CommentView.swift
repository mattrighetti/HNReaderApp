import SwiftUI

private enum CommentThreadLayout {
    static let avatarSize: CGFloat = 20
    static let headerHeight: CGFloat = 22
    static let verticalPadding: CGFloat = 10
    static let contentSpacing: CGFloat = 8
    static let childIndent: CGFloat = 24
    static let lineWidth: CGFloat = 1

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

    @StateObject private var model: CommentRepliesModel
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

        _model = StateObject(
            wrappedValue: CommentRepliesModel(
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
        item.kids?.count ?? 0
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

                if isCollapsed {
                    Button {
                        isCollapsed = false
                    } label: {
                        Text(replyCount > 0 ? "Comment collapsed · \(replyLabel)" : "Comment collapsed")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 28)
                } else {
                    commentBody
                        .padding(.leading, 28)

                    actions
                        .padding(.leading, 28)
                }
            }
            .overlay(alignment: .leading) {
                if !isCollapsed && repliesExpanded && replyCount > 0 && depth < 3 {
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
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.discussionURL.absoluteString, forType: .string)
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
                .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            Button {
                isCollapsed.toggle()
            } label: {
                Image(systemName: isCollapsed ? "plus" : "minus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: CommentThreadLayout.headerHeight, height: CommentThreadLayout.headerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand comment" : "Collapse comment and replies")
            .accessibilityLabel(isCollapsed ? "Expand comment" : "Collapse comment and replies")
        }
        .frame(height: CommentThreadLayout.headerHeight)
    }

    @ViewBuilder
    private var commentBody: some View {
        if depth >= 4, let parentAuthor {
            Text("Replying to \(parentAuthor)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }

        if item.deleted == true || item.dead == true {
            Text("This comment is no longer available.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else if let text = item.text {
            HTMLText(text: text, fontSize: 13, lineSpacing: 3)
                .lineLimit(canExpandText && !showFullText ? 8 : nil)

            if canExpandText {
                Button(showFullText ? "Show less" : "Read more") {
                    showFullText.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
            }
        }
    }

    private var actions: some View {
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
                .foregroundStyle(.orange)
            }

            Link(destination: item.discussionURL) {
                Label("Reply on HN", systemImage: "arrowshape.turn.up.left")
            }
            .help("Open this comment on Hacker News to reply")

            ShareLink(item: item.discussionURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    private var replyThread: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.replies.enumerated()), id: \.element.id) { index, reply in
                AnyView(CommentView(
                    item: reply,
                    storyAuthor: storyAuthor,
                    depth: depth + 1,
                    parentAuthor: author,
                    collapseAll: collapseAll,
                    previewThreads: previewThreads,
                    expandPreview: expandPreview
                ))
                .padding(.leading, depth < 3 ? CommentThreadLayout.childIndent : 0)
                .overlay(alignment: .leading) {
                    if depth < 3 {
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
                    .font(.caption)
                    .controlSize(.small)
                    .padding(.leading, 28)
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
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                .padding(.leading, 28)
                .padding(.vertical, 10)
            } else if model.hasMore && model.hasLoaded {
                Button {
                    Task {
                        await model.loadNextPage()
                    }
                } label: {
                    Label("More replies", systemImage: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .padding(.leading, 28)
                .padding(.vertical, 10)
            } else if model.hasMore {
                Button("Load replies") {
                    Task {
                        await model.loadNextPage()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.leading, 28)
                .padding(.vertical, 10)
            } else if model.hasLoaded && model.replies.isEmpty {
                Text("These replies are no longer available.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
                    .padding(.vertical, 10)
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

        let posted = Int(Date().addingTimeInterval(-3600).timeIntervalSince1970)
        let examples = """
        [
            {
                "id": 400,
                "by": "alex",
                "text": "The best interfaces make the conversation easy to follow. Small details like spacing and thread lines make a surprisingly big difference.",
                "kids": [401, 402],
                "time": \(posted)
            },
            {
                "id": 401,
                "parent": 400,
                "by": "samantha",
                "text": "Agreed. I especially like being able to collapse a whole branch without losing my place in the discussion.",
                "kids": [403],
                "time": \(posted + 600)
            },
            {
                "id": 402,
                "parent": 400,
                "by": "kai",
                "text": "And keeping the text readable as the thread gets deeper. A little indentation goes a long way.",
                "time": \(posted + 1200)
            },
            {
                "id": 403,
                "parent": 401,
                "by": "alex",
                "text": "Exactly. The curved connectors should show <i>who is replying to whom</i>, without making the text feel boxed in.",
                "kids": [404],
                "time": \(posted + 900)
            },
            {
                "id": 404,
                "parent": 403,
                "by": "jules",
                "text": "This feels much easier to scan. The author badge helps too.",
                "time": \(posted + 1500)
            },
            {
                "id": 450,
                "by": "taylor",
                "text": "A separate top-level thought: sharing a direct link to a comment is useful when a conversation has a lot of branches.",
                "time": \(posted + 1800)
            }
        ]
        """

        comments = (try? JSONDecoder().decode([Item].self, from: Data(examples.utf8))) ?? []
        let byID = Dictionary(uniqueKeysWithValues: comments.map { ($0.id, $0) })

        threads = Dictionary(uniqueKeysWithValues: comments.map { comment in
            (comment.id, (comment.kids ?? []).compactMap { byID[$0] })
        })
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
        .background(Color(nsColor: .textBackgroundColor))
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

#Preview("Comment threads · Collapsed", traits: .fixedLayout(width: 640, height: 240)) {
    CommentsPreview(collapsed: true)
        .preferredColorScheme(.dark)
}
#endif
