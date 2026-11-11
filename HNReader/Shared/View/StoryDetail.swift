import SwiftUI

#if DEBUG && os(iOS)
    import UIKit

    /// Observe UIKit independently of SwiftUI's appearance callbacks without changing navigation.
    private struct DiscussionLifecycleProbe: UIViewControllerRepresentable {
        let storyID: Int
        let instanceID: UUID

        func makeUIViewController(context: Context) -> Controller {
            Controller(storyID: storyID, instanceID: instanceID)
        }

        func updateUIViewController(_ controller: Controller, context: Context) {}

        static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
            controller.record("dismantle")
        }

        final class AttachmentView: UIView {
            var windowChanged: (() -> Void)?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                windowChanged?()
            }
        }

        final class Controller: UIViewController {
            let storyID: Int
            let instanceID: UUID

            init(storyID: Int, instanceID: UUID) {
                self.storyID = storyID
                self.instanceID = instanceID
                super.init(nibName: nil, bundle: nil)
            }

            required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

            override func loadView() {
                let attachment = AttachmentView()
                attachment.isUserInteractionEnabled = false
                attachment.windowChanged = { [weak self] in self?.record("windowChanged") }
                view = attachment
            }

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                record("willAppear")
            }

            override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                record("didAppear")
            }

            override func viewWillDisappear(_ animated: Bool) {
                super.viewWillDisappear(animated)
                record("willDisappear")
            }

            override func viewDidDisappear(_ animated: Bool) {
                super.viewDidDisappear(animated)
                record("didDisappear")
                DispatchQueue.main.async { [weak self] in self?.record("afterDisappear") }
            }

            func record(_ event: String) {
                var ancestors: [String] = []
                var controller = parent
                while let current = controller {
                    ancestors.append("\(String(describing: type(of: current)))@\(ObjectIdentifier(current))")
                    controller = current.parent
                }
                let window = viewIfLoaded?.window
                let frame = viewIfLoaded.map { $0.convert($0.bounds, to: window) } ?? .zero
                let intersectsWindow = window.map { $0.bounds.intersects(frame) } ?? false
                DiscussionDiagnostics.log("uikit.\(event) instance=\(instanceID) story=\(storyID) probe=\(ObjectIdentifier(self)) attached=\(window != nil) intersectsWindow=\(intersectsWindow) frame=\(frame) hidden=\(viewIfLoaded?.isHidden ?? true) movingFromParent=\(isMovingFromParent) beingDismissed=\(isBeingDismissed) transition=\(transitionCoordinator != nil) ancestors=\(ancestors)")
            }
        }
    }
#endif

#if DEBUG
    #Preview("Discussion") {
        if let item = PreviewData.stories.first {
            NavigationStack {
                StoryDetail(
                    item: item, initialComments: PreviewData.rootComments,
                    previewThreads: PreviewData.threads, loadsAutomatically: false)
            }
            .environment(PreviewData.appState())
        }
    }
#endif

struct StoryDetail: View {
    @State private var item: Item
    @State private var comments: [Item]
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var loadedCount: Int
    @State private var hasLoadedMetadata: Bool
    @State private var loadRequest = 0
    @State private var completedRequest = -1
    @State private var activeRequest = UUID()
    @State private var advanceAfterLoading = false
    @State private var diagnosticInstance = UUID()
    private let service = NewsService.shared

    private var hasMoreComments: Bool { loadedCount < (item.kids?.count ?? 0) }

    @Environment(AppState.self) private var appState

    @State private var threadsCollapsed = false
    @State private var commentFrames: [Int: CGRect] = [:]
    @State private var commentViewportHeight: CGFloat = 0
    @State private var pendingCommentID: Int?

    private let previewThreads: [Int: [Item]]?
    private let loadsAutomatically: Bool

    init(
        item: Item,
        initialComments: [Item]? = nil,
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
        _item = State(initialValue: item)
        _comments = State(initialValue: (initialComments ?? []).filter(\.isVisibleComment))
        _isLoading = State(
            initialValue: isLoading || (loadsAutomatically && initialComments == nil))
        _errorMessage = State(initialValue: errorMessage)
        _loadedCount = State(initialValue: initialComments == nil ? 0 : item.kids?.count ?? 0)
        _hasLoadedMetadata = State(initialValue: initialComments != nil)
    }

    private var navigation: CommentNavigation {
        CommentNavigation(
            ids: comments.map(\.id),
            frames: commentFrames,
            viewportHeight: commentViewportHeight
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StoryHeader(item: item, articleFont: appState.articleFont)

                    if let text = item.text, !text.isEmpty {
                        ArticleBody(text: text, articleFont: appState.articleFont)
                    }

                    DiscussionHeader(item: item, threadsCollapsed: $threadsCollapsed)

                    if comments.isEmpty && !isLoading && errorMessage == nil
                        && (hasLoadedMetadata || !loadsAutomatically) && !hasMoreComments
                    {
                        Text(
                            (item.descendants ?? 0) > 0
                                ? "No visible comments." : "No comments yet."
                        )
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                        .onAppear {
                            DiscussionDiagnostics.log("view.empty \(diagnosticState)")
                        }
                    }

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comments) { comment in
                            CommentView(
                                item: comment,
                                storyAuthor: item.by,
                                collapseAll: threadsCollapsed,
                                previewThreads: previewThreads
                            )
                            .id(comment.id)
                            .onAppear {
                                DiscussionDiagnostics.log("view.commentAppear story=\(item.id) comment=\(comment.id) collapsed=\(threadsCollapsed)")
                            }
                            #if os(macOS)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: CommentPositions.self,
                                            value: [
                                                comment.id: geometry.frame(
                                                    in: .named("discussionScroll"))
                                            ]
                                        )
                                    }
                                }
                            #endif
                        }
                    }
                    #if os(iOS)
                        .padding(.horizontal, -8)
                    #endif

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Retry Comments") {
                            loadRequest += 1
                        }
                        .clickableCursor()
                    }

                    if isLoading {
                        ProgressView("Loading conversation…")
                            .frame(maxWidth: .infinity)
                    } else if hasMoreComments && errorMessage == nil {
                        Button("Load More Comments") {
                            loadRequest += 1
                        }
                        .clickableCursor()
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                #if os(macOS)
                    .padding(32)
                #else
                    .padding(16)
                #endif
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            #if os(macOS)
                .coordinateSpace(name: "discussionScroll")
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.containerSize.height
                } action: { _, height in
                    commentViewportHeight = height
                }
                .onPreferenceChange(CommentPositions.self) { frames in
                    commentFrames = frames
                }
                .onChange(of: pendingCommentID) { _, id in
                    guard let id else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .top)
                    }

                    pendingCommentID = nil
                }
                .overlay(alignment: .bottomTrailing) {
                    if !comments.isEmpty {
                        CommentJumpControls(
                            canGoUp: navigation.target(for: .previous) != nil,
                            canGoDown: navigation.target(for: .next) != nil || hasMoreComments,
                            isLoading: isLoading,
                            previous: {
                                pendingCommentID = navigation.target(for: .previous)
                            },
                            next: {
                                jumpToNextComment()
                            }
                        )
                        .padding(.trailing, 24)
                        .padding(.bottom, 20)
                    }
                }
            #endif
        }
        .background(PlatformColors.textBackground)
        #if DEBUG && os(iOS)
            .background {
                DiscussionLifecycleProbe(storyID: item.id, instanceID: diagnosticInstance)
                    .allowsHitTesting(false)
            }
        #endif
        .toolbar {
            #if os(iOS)
                if let articleURL = item.articleURL {
                    Link(destination: articleURL) {
                        Label("Open Article", systemImage: "safari")
                    }
                    .accessibilityLabel("Open article in browser")
                }
            #endif

            Button {
                appState.toggleSaved(item)
            } label: {
                Label(
                    appState.isSaved(item) ? "Remove from Saved" : "Save Story",
                    systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                )
            }
            .clickableCursor()
            .keyboardShortcut("d", modifiers: .command)

            ShareLink(item: item.articleURL ?? item.discussionURL)
                .clickableCursor()
        }
        .onAppear {
            DiscussionDiagnostics.log("view.appear \(diagnosticState)")
        }
        .onDisappear {
            DiscussionDiagnostics.log("view.disappear \(diagnosticState)")
        }
        .task(id: loadRequest) {
            DiscussionDiagnostics.log("view.task \(diagnosticState)")
            if loadsAutomatically && completedRequest != loadRequest {
                await loadComments()
            } else {
                DiscussionDiagnostics.log("view.taskSkipped \(diagnosticState)")
            }
        }
    }

    private var diagnosticState: String {
        "instance=\(diagnosticInstance) \(DiscussionDiagnostics.summary(item)) visible=\(comments.count) loadedCount=\(loadedCount) hasMetadata=\(hasLoadedMetadata) loading=\(isLoading) hasMore=\(hasMoreComments) automatic=\(loadsAutomatically) attempt=\(loadRequest) completed=\(completedRequest) active=\(activeRequest) error=\(errorMessage != nil)"
    }

    @MainActor
    private func loadComments() async {
        let attempt = loadRequest
        let request = UUID()
        activeRequest = request
        isLoading = true
        errorMessage = nil
        let previousCount = comments.count
        DiscussionDiagnostics.log("view.loadStart request=\(request) \(diagnosticState)")
        defer {
            if activeRequest == request { isLoading = false }
            DiscussionDiagnostics.log("view.loadEnd request=\(request) cancelled=\(Task.isCancelled) \(diagnosticState)")
        }
        do {
            let result = try await service.discussionPage(
                item: item, offset: loadedCount, fetchMetadata: !hasLoadedMetadata,
                requestID: request)
            guard activeRequest == request, loadRequest == attempt, !Task.isCancelled else {
                DiscussionDiagnostics.log("view.resultDiscarded request=\(request) cancelled=\(Task.isCancelled) \(diagnosticState)")
                return
            }
            item = result.item
            comments += result.page.comments
            loadedCount = result.page.nextOffset
            hasLoadedMetadata = true
            completedRequest = attempt
            DiscussionDiagnostics.log("view.resultApplied request=\(request) added=\(result.page.comments.map(\.id)) \(diagnosticState)")
            if advanceAfterLoading && comments.count > previousCount {
                pendingCommentID = comments[previousCount].id
            }
            advanceAfterLoading = false
        } catch {
            let failure = error as NSError
            DiscussionDiagnostics.log("view.loadError request=\(request) domain=\(failure.domain) code=\(failure.code) cancelled=\(Task.isCancelled) \(diagnosticState)")
            guard activeRequest == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            advanceAfterLoading = false
        }
    }

    @MainActor
    private func jumpToNextComment() {
        if let id = navigation.target(for: .next) {
            pendingCommentID = id
        } else if loadsAutomatically && hasMoreComments && !isLoading {
            advanceAfterLoading = true
            loadRequest += 1
        }
    }
}

struct ArticleTitle: View {
    let title: String
    let articleFont: ArticleFont

    var body: some View {
        Text(title)
            .font(.custom(articleFont.titleFontName, size: 30))
            .textSelection(.enabled)
    }
}

struct ArticleBody: View {
    let text: String
    let articleFont: ArticleFont

    var body: some View {
        #if os(macOS)
            HTMLText(text: text, fontName: articleFont.fontName)
        #else
            HTMLText(text: text, fontSize: 17, lineSpacing: 6, fontName: articleFont.fontName)
        #endif
    }
}

private struct StoryHeader: View {
    let item: Item
    let articleFont: ArticleFont
    @Environment(AppState.self) private var appState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.urlHost?.uppercased() ?? "HACKER NEWS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.accentColor)

            ArticleTitle(title: item.title ?? "Untitled story", articleFont: articleFont)

            #if os(macOS)
                HStack(spacing: 8) {
                    if let author = item.by {
                        NavigationLink {
                            UserDetailView(username: author)
                        } label: {
                            Text(author)
                        }
                        .clickableCursor()
                        .buttonStyle(.plain)
                        .accessibilityLabel("View \(author)’s profile")
                    } else {
                        Text("Unknown author")
                    }

                    Text("·")

                    Text("\(item.timeStringRepresentation ?? "") ago")

                    Text("·")

                    Text("\(item.score ?? 0) points")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            #else
                HStack(spacing: 14) {
                    Label {
                        Text("\(item.score ?? 0) points")
                    } icon: {
                        Image(systemName: "arrow.up")
                            .fontWeight(.bold)
                    }

                    if let time = item.timeStringRepresentation {
                        Label {
                            Text("\(time) ago")
                        } icon: {
                            Image(systemName: "calendar")
                                .fontWeight(.bold)
                        }
                    }

                    if let author = item.by {
                        NavigationLink {
                            UserDetailView(username: author)
                        } label: {
                            Label {
                                Text(author)
                            } icon: {
                                Image(systemName: "person")
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View \(author)’s profile")
                    } else {
                        Label {
                            Text("Unknown author")
                        } icon: {
                            Image(systemName: "person")
                                .fontWeight(.bold)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            #endif

            #if os(macOS)
                HStack(spacing: 12) {
                    Link(destination: item.articleURL ?? item.discussionURL) {
                        Label(
                            "Open \(item.articleURL == nil ? "on Hacker News" : "Article")",
                            systemImage: "arrow.up.right"
                        )
                    }
                    .clickableCursor()
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.toggleSaved(item)
                    } label: {
                        Label(
                            appState.isSaved(item) ? "Saved" : "Save for Later",
                            systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .clickableCursor()
                    .buttonStyle(.bordered)
                }
            #endif
        }
    }
}

private struct DiscussionHeader: View {
    let item: Item
    @Binding var threadsCollapsed: Bool
    var body: some View {
        #if os(macOS)
            HStack {
                Label("Discussion", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)

                Text("\(item.descendants ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    threadsCollapsed.toggle()
                } label: {
                    Label(
                        threadsCollapsed ? "Expand threads" : "Collapse threads",
                        systemImage: threadsCollapsed ? "chevron.down" : "chevron.up"
                    )
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                Link("View on HN", destination: item.discussionURL)
                    .clickableCursor()
                    .font(.system(size: 10))
            }
        #else
            HStack(spacing: 10) {
                Label(
                    "\(item.descendants ?? 0) comments",
                    systemImage: "bubble.left.and.bubble.right"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    threadsCollapsed.toggle()
                } label: {
                    Image(systemName: threadsCollapsed ? "chevron.down" : "chevron.up")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(threadsCollapsed ? "Expand threads" : "Collapse threads")

                Link(destination: item.discussionURL) {
                    Label("View on HN", systemImage: "arrow.up.right")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View discussion on Hacker News")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        #endif
    }
}
