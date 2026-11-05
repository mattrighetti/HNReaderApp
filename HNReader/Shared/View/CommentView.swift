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
    @Environment(AppState.self) private var appState

    @State private var replies: [Item]
    @State private var nextOffset: Int
    @State private var hasLoaded: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var replyAttempt = 0
    @State private var completedAttempt = 0
    @State private var activeRequest = UUID()
    private let service = NewsService.shared
    private var hasMore: Bool { nextOffset < (item.kids?.count ?? 0) }
    @State private var isCollapsed: Bool
    @State private var repliesExpanded: Bool

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

        let initial = previewThreads?[item.id]
        _replies = State(initialValue: (initial ?? []).filter(\.isVisibleComment))
        _nextOffset = State(initialValue: initial == nil ? 0 : item.kids?.count ?? 0)
        _hasLoaded = State(initialValue: initial != nil)
        _isCollapsed = State(initialValue: collapseAll)
        _repliesExpanded = State(initialValue: expandPreview)
    }

    private var author: String {
        item.by ?? "Deleted user"
    }

    private var replyCount: Int {
        replies.count + max(0, (item.kids?.count ?? 0) - nextOffset)
    }

    private var replyLabel: String {
        "\(replyCount) \(replyCount == 1 ? "reply" : "replies")"
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
                if !isCollapsed && repliesExpanded && replyCount > 0
                    && depth < CommentThreadLayout.maximumIndentDepth
                {
                    ThreadStem()
                        .stroke(
                            CommentThreadLayout.lineColor(for: colorScheme),
                            style: StrokeStyle(
                                lineWidth: CommentThreadLayout.lineWidth, lineCap: .butt)
                        )
                        .padding(.bottom, -CommentThreadLayout.contentSpacing)
                        .frame(width: CommentThreadLayout.childIndent)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu {
                commentMenu
            }

            if !isCollapsed && repliesExpanded && replyCount > 0 {
                replyThread
            }
        }
        .padding(.vertical, CommentThreadLayout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(
            id: ReplyLoadRequest(expanded: !isCollapsed && repliesExpanded, attempt: replyAttempt)
        ) {
            guard !isCollapsed, repliesExpanded, hasMore,
                !hasLoaded || completedAttempt != replyAttempt
            else { return }
            await loadReplies()
        }
        .onChange(of: collapseAll) { _, collapsed in
            isCollapsed = collapsed
        }
    }

    @ViewBuilder
    private var commentMenu: some View {
        Button(
            appState.isSaved(item) ? "Remove Comment from Saved" : "Save Comment",
            systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
        ) {
            appState.toggleSaved(item)
        }

        Link(destination: item.discussionURL) {
            Label("Reply on Hacker News", systemImage: "arrowshape.turn.up.left")
        }

        ShareLink(item: item.discussionURL) {
            Label("Share Comment", systemImage: "square.and.arrow.up")
        }

        Button {
            #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.discussionURL.absoluteString, forType: .string)
            #else
                UIPasteboard.general.url = item.discussionURL
            #endif
        } label: {
            Label("Copy Comment Link", systemImage: "doc.on.doc")
        }

        Divider()

        Button {
            isCollapsed.toggle()
        } label: {
            Label(
                isCollapsed ? "Expand Comment" : "Collapse Comment",
                systemImage: isCollapsed ? "plus" : "minus"
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let username = item.by {
                NavigationLink {
                    UserDetailView(username: username)
                } label: {
                    authorIdentity
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("View \(username)’s profile")
            } else {
                authorIdentity
            }

            Button {
                isCollapsed.toggle()
            } label: {
                HStack(spacing: 8) {
                    if let time = item.timeStringRepresentation {
                        Text("· \(time)")
                            .font(.system(size: CommentThreadLayout.metadataFontSize))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isCollapsed ? "plus" : "minus")
                        .font(
                            .system(size: CommentThreadLayout.metadataFontSize, weight: .semibold)
                        )
                        .foregroundStyle(.secondary)
                        .frame(
                            width: CommentThreadLayout.touchTarget,
                            height: CommentThreadLayout.touchTarget
                        )
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .clickableCursor()
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand comment" : "Collapse comment and replies")
            .accessibilityLabel(isCollapsed ? "Expand comment" : "Collapse comment and replies")
            .accessibilityHint(
                isCollapsed ? "Expands this comment" : "Collapses this comment and its replies")
        }
        .frame(height: CommentThreadLayout.headerHeight)
    }

    private var authorIdentity: some View {
        HStack(spacing: 8) {
            CommentAvatar(author: author)

            Text(author)
                .font(.system(size: CommentThreadLayout.headerFontSize, weight: .semibold))
                .lineLimit(1)

            if item.by != nil && item.by == storyAuthor {
                Text("OP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Original poster")
            }
        }
    }

    @ViewBuilder
    private var commentBody: some View {
        if let text = item.text {
            CommentTextView(
                html: text,
                replyingTo: depth > CommentThreadLayout.maximumIndentDepth ? parentAuthor : nil
            )
        }
    }

    private var actions: some View {
        #if os(macOS)
            HStack(spacing: 16) {
                if replyCount > 0 {
                    Button {
                        toggleReplies()
                    } label: {
                        Label(
                            repliesExpanded ? "Hide replies" : replyLabel,
                            systemImage: repliesExpanded ? "chevron.up" : "bubble.left"
                        )
                    }
                    .clickableCursor()
                    .foregroundStyle(Color.accentColor)
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

                saveButton

                Spacer(minLength: 0)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        #else
            HStack(spacing: 8) {
                if replyCount > 0 {
                    Button {
                        toggleReplies()
                    } label: {
                        Label(
                            repliesExpanded ? "Hide replies" : replyLabel,
                            systemImage: repliesExpanded ? "chevron.up" : "bubble.left"
                        )
                        .frame(minHeight: CommentThreadLayout.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHint(
                        repliesExpanded
                            ? "Collapses this comment thread" : "Expands this comment thread")
                }

                Spacer(minLength: 0)

                saveButton
            }
            .font(.system(size: CommentThreadLayout.actionFontSize, weight: .semibold))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        #endif
    }

    private var saveButton: some View {
        Button {
            appState.toggleSaved(item)
        } label: {
            Label(
                appState.isSaved(item) ? "Saved" : "Save",
                systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
            )
            .frame(minHeight: CommentThreadLayout.touchTarget)
            .contentShape(Rectangle())
        }
        .clickableCursor()
        .foregroundStyle(appState.isSaved(item) ? Color.accentColor : .secondary)
        .accessibilityLabel(appState.isSaved(item) ? "Remove Comment from Saved" : "Save Comment")
        .accessibilityIdentifier("comment.save.\(item.id)")
    }

    private var replyThread: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(replies.enumerated()), id: \.element.id) { index, reply in
                CommentView(
                    item: reply,
                    storyAuthor: storyAuthor,
                    depth: depth + 1,
                    parentAuthor: author,
                    collapseAll: collapseAll,
                    previewThreads: previewThreads,
                    expandPreview: expandPreview
                )
                .padding(
                    .leading,
                    depth < CommentThreadLayout.maximumIndentDepth
                        ? CommentThreadLayout.childIndent : 0
                )
                .overlay(alignment: .leading) {
                    if depth < CommentThreadLayout.maximumIndentDepth {
                        ThreadBranch(isLast: index == replies.count - 1 && !hasMore)
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

            if isLoading {
                ProgressView("Loading replies…")
                    .font(.system(size: CommentThreadLayout.metadataFontSize))
                    .controlSize(.small)
                    .padding(.leading, CommentThreadLayout.bodyIndent)
                    .padding(.vertical, 12)
            } else if let error = errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Retry Replies") {
                        replyAttempt += 1
                    }
                    .clickableCursor()
                    .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                    .buttonStyle(.plain)
                    .frame(minHeight: CommentThreadLayout.touchTarget)
                }
                .padding(.leading, CommentThreadLayout.bodyIndent)
                .padding(.vertical, 10)
            } else if hasMore && hasLoaded {
                Button {
                    replyAttempt += 1
                } label: {
                    Label("More replies", systemImage: "arrow.turn.down.right")
                        .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.leading, CommentThreadLayout.bodyIndent)
                .frame(minHeight: CommentThreadLayout.touchTarget)
            } else if hasMore {
                ProgressView("Loading replies…")
                    .font(.system(size: CommentThreadLayout.actionFontSize, weight: .medium))
                    .padding(.leading, CommentThreadLayout.bodyIndent)
                    .padding(.vertical, 12)
                    .frame(minHeight: CommentThreadLayout.touchTarget)
            }
        }
    }

    private struct ReplyLoadRequest: Equatable {
        let expanded: Bool
        let attempt: Int
    }

    private func toggleReplies() { repliesExpanded.toggle() }

    @MainActor
    private func loadReplies() async {
        let attempt = replyAttempt
        let request = UUID()
        activeRequest = request
        isLoading = true
        errorMessage = nil
        defer { if activeRequest == request { isLoading = false } }
        do {
            let page = try await service.commentPage(
                ids: item.kids ?? [], offset: nextOffset, pageSize: 15)
            guard activeRequest == request, replyAttempt == attempt,
                repliesExpanded, !isCollapsed, !Task.isCancelled
            else { return }
            replies += page.comments
            nextOffset = page.nextOffset
            hasLoaded = true
            completedAttempt = attempt
        } catch {
            guard activeRequest == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

/// The vertical spine starts directly below the parent's avatar. Each child has
/// a quarter-circle elbow ending at its avatar; the last child's spine stops there.
private struct ThreadStem: Shape {
    func path(in rect: CGRect) -> Path {
        let startY =
            CommentThreadLayout.headerHeight / 2
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
        @State private var appState = PreviewData.appState()

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
            .environment(appState)
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
                .environment(PreviewData.appState())
            }
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Comment threads · Collapsed", traits: .fixedLayout(width: 640, height: 240)) {
        CommentsPreview(collapsed: true)
            .preferredColorScheme(.dark)
    }

    #Preview("Saved comment", traits: .fixedLayout(width: 390, height: 600)) {
        if let comment = PreviewData.comments.first {
            NavigationStack {
                SavedCommentDetail(item: comment, previewThreads: PreviewData.threads)
            }
            .environment(PreviewData.appState())
        }
    }
#endif
