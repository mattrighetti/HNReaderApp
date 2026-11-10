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
    private let showsUpvotes: Bool

    init(
        username: String,
        user: User? = nil,
        initialComments: [Item] = [],
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true,
        title: String? = nil,
        showsMacDismissButton: Bool = true,
        showsUpvotes: Bool = false
    ) {
        self.username = username
        _user = State(initialValue: user)
        self.initialComments = initialComments
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
        self.title = title ?? username
        self.showsMacDismissButton = showsMacDismissButton
        self.showsUpvotes = showsUpvotes
    }

    private var profileURL: URL {
        userURL(path: "user")
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical) {
                VStack {
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
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .safeAreaPadding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
        }
        .background { profileBackground.ignoresSafeArea() }
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

    private var profileBackground: some View {
        PlatformColors.textBackground
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
        VStack(alignment: .leading, spacing: 26) {
            profileHeader(user)

            if let about = user.about, !about.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("About")

                    #if os(macOS)
                        HTMLText(text: about)
                    #else
                        HTMLText(text: about, fontSize: 17, lineSpacing: 6)
                    #endif
                }
            }

            profileOptions(user)

            profileCTA
        }
    }

    private var profileCTA: some View {
        HStack {
            Link(destination: profileURL) {
                HStack(spacing: 10) {
                    Text("Open on Hacker News")
                    Image(systemName: "arrow.up.right")
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .frame(height: 58)
                    .background(Color(white: 0.20), in: Capsule())
            }
        }
        .padding(.bottom, 8)
        .clickableCursor()
        .help("Open profile on Hacker News")
    }

    private func profileHeader(_ user: User) -> some View {
        VStack(spacing: 12) {
            UserAvatar(username: user.id, size: 52, isProminent: true)

            VStack(spacing: 4) {
                Text(user.id)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .textSelection(.enabled)

                Text("Member since \(joinedDate(user.created)) · \(membershipAge(user.created))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                statistic(value: user.karma.formatted(), label: "Karma", icon: "arrowtriangle.up.fill")

                Divider()
                    .frame(height: 26)

                statistic(value: (user.submitted?.count ?? 0).formatted(), label: "Submissions")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .solidCard(cornerRadius: 26)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileOptions(_ user: User) -> some View {
        VStack(spacing: 0) {
            if showsUpvotes {
                NavigationLink {
                    HNUpvotedItemsView(
                        username: user.id,
                        loadsAutomatically: loadsAutomatically
                    )
                } label: {
                    profileOptionLabel("Upvotes", systemImage: "arrow.up.circle")
                }

                Divider()
                    .padding(.leading, 44)
            }

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

            Link(destination: userURL(path: "submitted")) {
                profileOptionLabel("Submissions", systemImage: "doc.text", isExternal: true)
            }

            Divider()
                .padding(.leading, 44)

            Link(destination: userURL(path: "favorites")) {
                profileOptionLabel("Favorites", systemImage: "star", isExternal: true)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .solidCard(cornerRadius: 22)
    }

    private func profileOptionLabel(
        _ title: String,
        systemImage: String,
        isExternal: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Spacer()

            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func statistic(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            }

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private func joinedDate(_ timestamp: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
            .formatted(.dateTime.month(.abbreviated).year())
    }

    private func membershipAge(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        return years == 1 ? "1 year" : "\(years) years"
    }

    private func userURL(path: String) -> URL {
        var components = URLComponents(string: "https://news.ycombinator.com/\(path)")!
        components.queryItems = [URLQueryItem(name: "id", value: username)]
        return components.url!
    }
}

private extension View {
    @ViewBuilder
    func solidCard(cornerRadius: CGFloat) -> some View {
        background(
            PlatformColors.textBackground,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(PlatformColors.separator.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct UserAvatar: View {
    let username: String
    var size: CGFloat = 58
    var isProminent = false

    private var color: Color {
        let hue = username.utf8.reduce(0) { ($0 * 31 + Int($1)) % 360 }
        return Color(hue: Double(hue) / 360, saturation: 0.42, brightness: 0.78)
    }

    var body: some View {
        Text(String(username.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(isProminent ? .white : color)
            .frame(width: size, height: size)
            .background {
                if isProminent {
                    Circle().fill(LinearGradient(colors: [.orange, Color(red: 0.94, green: 0.35, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Circle().fill(color.opacity(0.13))
                }
            }
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
