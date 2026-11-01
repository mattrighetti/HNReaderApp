import SwiftUI

struct ItemList: View {
    let rows: [StoryRow]
    let revision: UUID

    @Binding var selectedID: Int?

    let title: String
    let subtitle: String
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let paginationError: String?
    let errorMessage: String?
    let isSaved: Bool
    let isSearching: Bool

    @Binding var unreadOnly: Bool

    let refresh: () async -> Void
    let loadMore: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(rows.count) stories")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Toggle("Unread only", isOn: $unreadOnly)
                        .toggleStyle(.button)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Show only stories you haven’t read")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Couldn’t load stories", systemImage: "wifi.exclamationmark")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        Task {
                            await refresh()
                        }
                    }
                }
                .padding()
            }

            if isLoading && rows.isEmpty {
                Spacer()

                ProgressView("Gathering stories…")

                Spacer()
            } else if rows.isEmpty && errorMessage == nil {
                ContentUnavailableView {
                    Label(
                        isSaved ? "Your reading list awaits" : "No stories to show",
                        systemImage: isSaved ? "bookmark" : "magnifyingglass"
                    )
                } description: {
                    Text(
                        isSearching
                            ? "Try a different search."
                            : unreadOnly
                            ? "You’re all caught up. Turn off the unread filter to see more."
                            : isSaved
                            ? "Save a story to come back to it later."
                            : "Refresh to check for stories."
                    )
                }
            } else {
                List(selection: $selectedID) {
                    ForEach(rows) { row in
                        ItemCell(item: row.item, rank: row.rank)
                            .help(row.item.title ?? "")
                            .frame(height: StoryRowLayout.height)
                            .tag(row.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(.primary.opacity(0.09))
                                    .frame(height: 1)
                            }
                            .listRowSeparator(.hidden)
                    }

                    if hasMore && !isSaved && !isSearching {
                        paginationFooter
                    }
                }
                .listStyle(.inset)
                .environment(\.defaultMinListRowHeight, StoryRowLayout.height)
                .transaction {
                    $0.animation = nil
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle(title)
        .toolbar {
            if !isSaved {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isLoading)
            }
        }
    }

    private var paginationFooter: some View {
        VStack(spacing: 8) {
            if let paginationError {
                Text(paginationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Retry Loading Stories") {
                    Task {
                        await loadMore()
                    }
                }
                .buttonStyle(.borderless)
            } else if isLoadingMore {
                ProgressView("Loading next 30 stories…")
                    .controlSize(.small)
            } else {
                Text("More stories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .listRowSeparator(.hidden)
        .id(rows.last?.id)
        .task(id: revision) {
            if paginationError == nil {
                await loadMore()
            }
        }
    }

}

struct StoryDetail: View {
    let item: Item

    @EnvironmentObject private var appState: AppState

    @State private var comments: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadedCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.urlHost?.uppercased() ?? "HACKER NEWS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.orange)

                    Text(item.title ?? "Untitled story")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Text(item.by ?? "Unknown author")

                        Text("·")

                        Text("\(item.timeStringRepresentation ?? "") ago")

                        Text("·")

                        Text("\(item.score ?? 0) points")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Link(destination: item.articleURL ?? item.discussionURL) {
                            Label(
                                "Open \(item.articleURL == nil ? "on Hacker News" : "Article")",
                                systemImage: "arrow.up.right"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button {
                            appState.toggleSaved(item)
                        } label: {
                            Label(
                                appState.isSaved(item) ? "Saved" : "Save for Later",
                                systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let text = item.text, !text.isEmpty {
                    HTMLText(text: text)
                }

                Divider()

                HStack {
                    Label("Discussion", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)

                    Text("\(item.descendants ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Link("View on HN", destination: item.discussionURL)
                        .font(.caption)
                }

                if comments.isEmpty && !isLoading && errorMessage == nil {
                    Text("No comments yet. Be the first to join the conversation on Hacker News.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                }

                ForEach(comments) { comment in
                    CommentView(item: comment)

                    Divider()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Retry Comments") {
                        Task {
                            await loadComments()
                        }
                    }
                }

                if isLoading {
                    ProgressView("Loading conversation…")
                        .frame(maxWidth: .infinity)
                } else if loadedCount < (item.kids?.count ?? 0) && errorMessage == nil {
                    Button("Load More Comments") {
                        Task {
                            await loadComments()
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            Button {
                appState.toggleSaved(item)
            } label: {
                Label(
                    appState.isSaved(item) ? "Remove from Saved" : "Save Story",
                    systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                )
            }
            .keyboardShortcut("d", modifiers: .command)

            ShareLink(item: item.articleURL ?? item.discussionURL)
        }
        .task {
            await loadComments()
        }
    }

    @MainActor private func loadComments() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let ids = Array((item.kids ?? []).dropFirst(loadedCount).prefix(20))
            let result = try await NewsService.shared.items(ids: ids)
            try Task.checkCancellation()

            comments += result
            loadedCount += ids.count
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CommentView: View {
    let item: Item

    @State private var expanded = false
    @State private var replies: [Item] = []
    @State private var loaded = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.by ?? "Deleted user")
                    .fontWeight(.semibold)

                Text("\(item.timeStringRepresentation ?? "") ago")
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .font(.caption)

            if item.deleted == true || item.dead == true {
                Text("Comment unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let text = item.text {
                HTMLText(text: text)
            }

            if let kids = item.kids, !kids.isEmpty {
                Button {
                    expanded.toggle()
                } label: {
                    Label(
                        expanded ? "Hide replies" :
                            "\(kids.count) \(kids.count == 1 ? "reply" : "replies")",
                        systemImage: expanded ? "chevron.down" : "chevron.right"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)

                if expanded {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(replies) { reply in
                            // Type erasure allows a recursively nested SwiftUI view.
                            AnyView(CommentView(item: reply))
                        }

                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Retry Replies") {
                                Task {
                                    await loadReplies()
                                }
                            }
                        } else if loaded && loadedCount < kids.count && !isLoading {
                            Button("More Replies") {
                                Task {
                                    await loadReplies()
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.leading, 16)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(.orange.opacity(0.2))
                            .frame(width: 2)
                        }
                    .task {
                        if !loaded {
                            await loadReplies()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor private func loadReplies() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let ids = Array((item.kids ?? []).dropFirst(loadedCount).prefix(15))
            let result = try await NewsService.shared.items(ids: ids)
            try Task.checkCancellation()

            replies += result
            loadedCount += ids.count
            loaded = true
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
