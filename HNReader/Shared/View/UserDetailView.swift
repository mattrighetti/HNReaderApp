import SwiftUI

struct UserDetailView: View {
    let username: String
    @State private var user: User?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var retryRequest = 0
    @State private var activeRequest = UUID()
    private let service = NewsService.shared

    @Environment(\.dismiss) private var dismiss

    private let loadsAutomatically: Bool
    private let initialComments: [Item]
    private let previewThreads: [Int: [Item]]?
    private let title: String
    private let showsMacDismissButton: Bool

    init(
        username: String,
        user: User? = nil,
        initialComments: [Item] = [],
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true,
        title: String? = nil,
        showsMacDismissButton: Bool = true
    ) {
        self.username = username
        _user = State(initialValue: user)
        self.initialComments = initialComments
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
        self.title = title ?? username
        self.showsMacDismissButton = showsMacDismissButton
    }

    private var profileURL: URL {
        userURL(path: "user")
    }

    var body: some View {
        ScrollView {
            Group {
                if let user = user {
                    profile(user)
                } else if isLoading || errorMessage == nil {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let errorMessage = errorMessage {
                    ContentUnavailableView {
                        Label(
                            "Couldn’t load profile",
                            systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            retryRequest += 1
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
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
                if showsMacDismissButton {
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
                await loadUser(forceRefresh: true)
            }
        }
        .task(id: retryRequest) {
            if loadsAutomatically { await loadUser() }
        }
    }

    @MainActor
    private func loadUser(forceRefresh: Bool = false) async {
        guard !Task.isCancelled else { return }
        if user != nil && !forceRefresh { return }
        let request = UUID()
        activeRequest = request
        isLoading = true
        errorMessage = nil
        defer { if activeRequest == request { isLoading = false } }
        do {
            guard let result = try await service.user(id: username, forceRefresh: forceRefresh)
            else {
                throw URLError(.resourceUnavailable)
            }
            try Task.checkCancellation()
            guard activeRequest == request else { return }
            user = result
        } catch {
            if activeRequest == request && !Task.isCancelled {
                errorMessage = error.localizedDescription
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
        components.queryItems = [URLQueryItem(name: "id", value: username)]
        return components.url!
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
                    created: 1_160_418_092,
                    karma: 155_782,
                    about:
                        "Bug fixer. <a href=\"https://ycombinator.com\">Y Combinator</a> cofounder.",
                    submitted: Array(1...1320)
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
