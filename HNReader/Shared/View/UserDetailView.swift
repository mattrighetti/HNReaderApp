import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
private final class UserDetailViewModel {
    let username: String

    private(set) var user: User?
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?

    private let service: NewsService

    init(
        username: String,
        service: NewsService = .shared,
        user: User? = nil
    ) {
        self.username = username
        self.service = service
        self.user = user
        isLoading = false
    }

    func load(forceRefresh: Bool = false) async {
        guard !isLoading, !Task.isCancelled else { return }
        if user != nil && !forceRefresh { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            guard let loadedUser = try await service.user(
                id: username,
                forceRefresh: forceRefresh
            ) else {
                throw URLError(.resourceUnavailable)
            }

            try Task.checkCancellation()
            user = loadedUser
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

}

struct UserDetailView: View {
    @State private var model: UserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    private let loadsAutomatically: Bool
    private let initialComments: [Item]
    private let previewThreads: [Int: [Item]]?

    init(
        username: String,
        user: User? = nil,
        initialComments: [Item] = [],
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true
    ) {
        _model = State(
            initialValue: UserDetailViewModel(
                username: username,
                user: user
            )
        )
        self.initialComments = initialComments
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
    }

    private var profileURL: URL {
        userURL(path: "user")
    }

    var body: some View {
        ScrollView {
            Group {
                if let user = model.user {
                    profile(user)
                } else if model.isLoading || model.errorMessage == nil {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let errorMessage = model.errorMessage {
                    ContentUnavailableView {
                        Label("Couldn’t load profile", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load(forceRefresh: true) }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(PlatformColors.textBackground)
        .navigationTitle(model.username)
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
                .help("Back to story")
                .accessibilityLabel("Back to story")
            }
            #else
            Link(destination: profileURL) {
                Label("View on HN", systemImage: "safari")
            }
            .clickableCursor()
            .help("View profile on Hacker News")
            #endif
        }
        .refreshable {
            if loadsAutomatically {
                await model.load(forceRefresh: true)
            }
        }
        .task {
            if loadsAutomatically {
                await model.load()
            }
        }
    }

    private func profile(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 16) {
                UserAvatar(username: user.id)

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.id)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .textSelection(.enabled)

                    Text("Member since \(joinedDate(user.created))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                statistic(value: user.karma.formatted(), label: "Karma")

                Divider()
                    .frame(height: 36)

                statistic(value: (user.submitted?.count ?? 0).formatted(), label: "Submissions")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            if let about = user.about, !about.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)

                    #if os(macOS)
                    HTMLText(text: about)
                    #else
                    HTMLText(text: about, fontSize: 17, lineSpacing: 6)
                    #endif
                }
            }

            profileOptions(user)
        }
    }

    private func profileOptions(_ user: User) -> some View {
        VStack(spacing: 0) {
            Link(destination: userURL(path: "submitted")) {
                profileOptionLabel("Submissions", systemImage: "doc.text", isExternal: true)
            }

            Divider()
                .padding(.leading, 44)

            NavigationLink {
                UserCommentsView(
                    username: user.id,
                    submitted: user.submitted ?? [],
                    initialComments: initialComments,
                    previewThreads: previewThreads,
                    loadsAutomatically: loadsAutomatically
                )
            } label: {
                profileOptionLabel("Comments", systemImage: "bubble.left.and.bubble.right")
            }

            Divider()
                .padding(.leading, 44)

            Link(destination: userURL(path: "favorites")) {
                profileOptionLabel("Favorites", systemImage: "star", isExternal: true)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func profileOptionLabel(
        _ title: String,
        systemImage: String,
        isExternal: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func joinedDate(_ timestamp: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
            .formatted(date: .abbreviated, time: .omitted)
    }

    private func userURL(path: String) -> URL {
        var components = URLComponents(string: "https://news.ycombinator.com/\(path)")!
        components.queryItems = [URLQueryItem(name: "id", value: model.username)]
        return components.url!
    }
}

@MainActor
@Observable
private final class UserCommentsViewModel {
    let username: String

    private(set) var comments: [Item]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let submitted: [Int]
    private let service: NewsService
    private var submittedOffset = 0

    var hasMoreComments: Bool {
        submittedOffset < submitted.count
    }

    init(
        username: String,
        submitted: [Int],
        service: NewsService = .shared,
        comments: [Item] = []
    ) {
        self.username = username
        self.submitted = submitted
        self.service = service
        self.comments = comments
    }

    func load(forceRefresh: Bool = false) async {
        guard !isLoading, !Task.isCancelled else { return }

        if forceRefresh {
            submittedOffset = 0
            comments = []
        }

        guard hasMoreComments else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            var page: [Item] = []
            var scannedCount = 0

            // The HN API combines stories and comments in `submitted`. Scan a
            // bounded window so opening a prolific user's comments stays quick.
            repeat {
                let ids = Array(submitted.dropFirst(submittedOffset).prefix(20))
                guard !ids.isEmpty else { break }

                let items = try await service.items(ids: ids, forceRefresh: forceRefresh)
                try Task.checkCancellation()

                page += items.filter {
                    $0.type == .comment
                        && $0.isVisibleComment
                        && $0.by == username
                }
                submittedOffset += ids.count
                scannedCount += ids.count
            } while page.count < 15 && hasMoreComments && scannedCount < 80

            let knownIDs = Set(comments.map(\.id))
            comments += page.filter { !knownIDs.contains($0.id) }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct UserCommentsView: View {
    @State private var model: UserCommentsViewModel

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
        _model = State(
            initialValue: UserCommentsViewModel(
                username: username,
                submitted: submitted,
                comments: initialComments
            )
        )
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
    }

    private var threadsURL: URL {
        var components = URLComponents(string: "https://news.ycombinator.com/threads")!
        components.queryItems = [URLQueryItem(name: "id", value: model.username)]
        return components.url!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if model.comments.isEmpty && model.isLoading {
                    ProgressView("Loading comments…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if model.comments.isEmpty && !model.hasMoreComments {
                    ContentUnavailableView(
                        "No Comments",
                        systemImage: "bubble.left",
                        description: Text("This user doesn’t have any visible comments.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.comments) { comment in
                            CommentView(
                                item: comment,
                                previewThreads: previewThreads
                            )
                        }
                    }
                }

                if let errorMessage = model.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Retry") {
                            Task { await model.load() }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 12)
                } else if model.isLoading && !model.comments.isEmpty {
                    ProgressView("Loading more comments…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else if model.hasMoreComments && loadsAutomatically {
                    Button("Load More Comments") {
                        Task { await model.load() }
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
                await model.load(forceRefresh: true)
            }
        }
        .task {
            if loadsAutomatically {
                await model.load()
            }
        }
    }
}

private struct UserAvatar: View {
    let username: String

    private var color: Color {
        let hue = username.utf8.reduce(0) { ($0 * 31 + Int($1)) % 360 }
        return Color(hue: Double(hue) / 360, saturation: 0.42, brightness: 0.78)
    }

    var body: some View {
        Text(String(username.prefix(1)).uppercased())
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 58, height: 58)
            .background(color.opacity(0.13), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(color.opacity(0.22), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("User profile") {
    NavigationStack {
        UserDetailView(
            username: "pg",
            user: User(
                id: "pg",
                created: 1160418092,
                karma: 155_782,
                about: "Bug fixer. <a href=\"https://ycombinator.com\">Y Combinator</a> cofounder.",
                submitted: Array(1 ... 1320)
            ),
            initialComments: PreviewData.rootComments,
            previewThreads: PreviewData.threads,
            loadsAutomatically: false
        )
    }
    .environment(PreviewData.appState())
}

#Preview("iOS · Live mattrighetti") {
    NavigationStack {
        UserDetailView(username: "mattrighetti")
    }
    .environment(PreviewData.appState())
}
#endif
