import SwiftUI

struct UserCommentsView: View {
    let username: String
    @State private var submittedIDs: [Int]
    @State private var comments: [Item]
    @State private var nextOffset = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadRequest = 0
    @State private var completedRequest = -1
    @State private var activeRequest = UUID()
    @State private var retryRefresh = false
    private let service = NewsService.shared
    private var hasMoreComments: Bool { nextOffset < submittedIDs.count }

    @Environment(\.dismiss) private var dismiss

    private let loadsAutomatically: Bool
    private let previewThreads: [Int: [Item]]?

    init(
        username: String,
        submitted: [Int],
        initialComments: [Item] = [],
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true
    ) {
        self.username = username
        _submittedIDs = State(initialValue: submitted)
        _comments = State(initialValue: initialComments)
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
    }

    private var threadsURL: URL {
        var components = URLComponents(string: "https://news.ycombinator.com/threads")!
        components.queryItems = [URLQueryItem(name: "id", value: username)]
        return components.url!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if comments.isEmpty && isLoading {
                    ProgressView("Loading comments…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if comments.isEmpty && !hasMoreComments && errorMessage == nil {
                    ContentUnavailableView(
                        "No Comments",
                        systemImage: "bubble.left",
                        description: Text("This user doesn’t have any visible comments.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comments) { comment in
                            CommentView(
                                item: comment,
                                previewThreads: previewThreads
                            )
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Retry") {
                            loadRequest += 1
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 12)
                } else if isLoading && !comments.isEmpty {
                    ProgressView("Loading more comments…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else if hasMoreComments && loadsAutomatically {
                    Button("Load More Comments") {
                        loadRequest += 1
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(PlatformColors.textBackground)
        .navigationTitle("Comments")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .help("Back to profile")
                    .accessibilityLabel("Back to profile")
                }
            #else
                Link(destination: threadsURL) {
                    Label("View on HN", systemImage: "safari")
                }
                .clickableCursor()
                .help("View comments on Hacker News")
            #endif
        }
        .refreshable {
            if loadsAutomatically {
                await loadComments(forceRefresh: true)
            }
        }
        .task(id: loadRequest) {
            if loadsAutomatically && completedRequest != loadRequest {
                await loadComments(forceRefresh: retryRefresh)
            }
        }
    }
    @MainActor
    private func loadComments(forceRefresh: Bool = false) async {
        let attempt = loadRequest
        guard !Task.isCancelled else { return }
        guard forceRefresh || hasMoreComments else { return }
        let request = UUID()
        activeRequest = request
        retryRefresh = forceRefresh
        isLoading = true
        errorMessage = nil
        defer { if activeRequest == request { isLoading = false } }
        do {
            let result = try await service.userCommentPage(
                username: username, submitted: submittedIDs, offset: nextOffset,
                forceRefresh: forceRefresh)
            try Task.checkCancellation()
            guard activeRequest == request, loadRequest == attempt else { return }
            let known = Set((forceRefresh ? [] : comments).map(\.id))
            let page = result.page.comments.filter { !known.contains($0.id) }
            comments = forceRefresh ? page : comments + page
            submittedIDs = result.submitted
            nextOffset = result.page.nextOffset
            completedRequest = attempt
            retryRefresh = false
        } catch {
            if activeRequest == request && !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

}

#if DEBUG
    #Preview("User comments") {
        NavigationStack {
            UserCommentsView(
                username: "alex", submitted: PreviewData.comments.map(\.id),
                initialComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads, loadsAutomatically: false)
        }
        .environment(PreviewData.appState())
    }
#endif
