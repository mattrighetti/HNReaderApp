import SwiftUI

struct HNAccountView: View {
    private enum Field: Hashable {
        case username
        case password
    }

    @State private var account: HNAuthenticatedAccount?
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var hasRestoredSession: Bool
    @State private var isSigningIn = false
    @State private var signInRequest = 0
    @State private var logoutRequest = 0
    @State private var showsLogoutConfirmation = false
    @FocusState private var focusedField: Field?

    private let authenticationClient: HNAuthenticationClient
    private let previewUser: User?
    private let loadsAutomatically: Bool

    init(
        authenticationClient: HNAuthenticationClient = .shared,
        account: HNAuthenticatedAccount? = nil,
        previewUser: User? = nil,
        loadsAutomatically: Bool = true
    ) {
        self.authenticationClient = authenticationClient
        self.previewUser = previewUser
        self.loadsAutomatically = loadsAutomatically
        _account = State(initialValue: account)
        _hasRestoredSession = State(initialValue: !loadsAutomatically)
    }

    var body: some View {
        Group {
            if !hasRestoredSession {
                ProgressView("Checking your Hacker News account…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let account {
                authenticatedContent(account)
            } else {
                signInForm
            }
        }
        .background(PlatformColors.textBackground)
        .navigationTitle(account?.username ?? "Hacker News Account")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if account != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(
                            "Sign Out",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            role: .destructive
                        ) {
                            showsLogoutConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Account actions")
                    .help("Account actions")
                }
            }
        }
        .task {
            await restoreSession()
        }
        .task(id: signInRequest) {
            guard signInRequest > 0 else { return }
            await signIn()
        }
        .task(id: logoutRequest) {
            guard logoutRequest > 0 else { return }
            await logout()
        }
        .confirmationDialog(
            "Sign out of Hacker News?",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                logoutRequest += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign in again at any time.")
        }
    }

    private var signInForm: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Sign in to Hacker News")
                        .font(.title2.weight(.semibold))
                }

                VStack(spacing: 14) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                }
                .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isSigningIn ? "Signing In…" : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)

                Text("Your password is sent directly to Hacker News over HTTPS and is not stored by HNReader.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func authenticatedContent(_ account: HNAuthenticatedAccount) -> some View {
        UserDetailView(
            username: account.username,
            user: previewUser,
            loadsAutomatically: loadsAutomatically,
            title: "Profile",
            showsMacDismissButton: false,
            showsUpvotes: true
        )
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isSigningIn
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        signInRequest += 1
    }

    @MainActor
    private func restoreSession() async {
        guard loadsAutomatically, !Task.isCancelled else { return }
        account = await authenticationClient.currentAccount()
        guard !Task.isCancelled else { return }
        hasRestoredSession = true
    }

    @MainActor
    private func signIn() async {
        guard canSubmit, !Task.isCancelled else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let result = try await authenticationClient.login(
                username: username,
                password: password
            )
            try Task.checkCancellation()
            password = ""
            account = result
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func logout() async {
        await authenticationClient.logout()
        guard !Task.isCancelled else { return }
        password = ""
        errorMessage = nil
        account = nil
    }
}

struct HNUpvotedItemsView: View {
    private struct Content {
        var items: [Item] = []
        var nextPage = 1
        var hasMore = true
        var errorMessage: String?
    }

    let username: String

    @State private var selection = HNUpvoteKind.submissions
    @State private var content: [HNUpvoteKind: Content]
    @State private var isLoading = false
    @State private var activeRequest = UUID()

    private let authenticationClient: HNAuthenticationClient
    private let service: NewsService
    private let loadsAutomatically: Bool

    init(
        username: String,
        authenticationClient: HNAuthenticationClient = .shared,
        service: NewsService = .shared,
        initialSubmissions: [Item] = [],
        initialComments: [Item] = [],
        loadsAutomatically: Bool = true
    ) {
        self.username = username
        self.authenticationClient = authenticationClient
        self.service = service
        self.loadsAutomatically = loadsAutomatically
        _content = State(initialValue: [
            .submissions: Content(
                items: initialSubmissions,
                nextPage: initialSubmissions.isEmpty ? 1 : 2,
                hasMore: loadsAutomatically
            ),
            .comments: Content(
                items: initialComments,
                nextPage: initialComments.isEmpty ? 1 : 2,
                hasMore: loadsAutomatically
            ),
        ])
    }

    private var selectedContent: Content {
        content[selection, default: Content()]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Upvote type", selection: $selection) {
                    ForEach(HNUpvoteKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isLoading)

                if selectedContent.items.isEmpty && isLoading {
                    ProgressView("Loading upvotes…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if selectedContent.items.isEmpty,
                          selectedContent.errorMessage == nil
                {
                    ContentUnavailableView(
                        selection == .submissions ? "No Upvoted Stories" : "No Upvoted Comments",
                        systemImage: "arrow.up.circle",
                        description: Text("Your upvotes from Hacker News will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else if selection == .submissions {
                    LazyVStack(spacing: 0) {
                        ForEach(StoryRow.savedRows(for: selectedContent.items)) { row in
                            NavigationLink {
                                StoryDetail(item: row.item)
                            } label: {
                                ItemCell(item: row.item, rank: row.rank)
                                    .frame(minHeight: StoryRowLayout.minimumHeight)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(selectedContent.items) { comment in
                            VStack(alignment: .leading, spacing: 0) {
                                CommentView(item: comment, showsContextAction: true)

                                Divider()
                            }
                        }
                    }
                }

                footer
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(PlatformColors.textBackground)
        .navigationTitle("Upvotes")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            if loadsAutomatically {
                await load(reset: true)
            }
        }
        .task(id: selection) {
            guard loadsAutomatically, selectedContent.items.isEmpty else { return }
            await load()
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let errorMessage = selectedContent.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Try Again") {
                    Task { await load() }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 12)
        } else if isLoading && !selectedContent.items.isEmpty {
            ProgressView("Loading more…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if selectedContent.hasMore && loadsAutomatically {
            Button("Load More") {
                Task { await load() }
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @MainActor
    private func load(reset: Bool = false) async {
        guard !isLoading, !Task.isCancelled else { return }
        let kind = selection
        var current = content[kind, default: Content()]
        guard reset || current.hasMore else { return }

        let request = UUID()
        activeRequest = request
        isLoading = true
        current.errorMessage = nil
        if reset {
            current.nextPage = 1
        }
        content[kind] = current
        defer { if activeRequest == request { isLoading = false } }

        do {
            let page = try await authenticationClient.upvotedItems(
                username: username,
                kind: kind,
                page: current.nextPage
            )
            let items = try await service.items(ids: page.ids, forceRefresh: reset)
            try Task.checkCancellation()
            guard activeRequest == request, selection == kind else { return }

            let previousItems = reset ? [] : current.items
            let knownIDs = Set(previousItems.map(\.id))
            current.items = previousItems + displayableItems(items, for: kind)
                .filter { !knownIDs.contains($0.id) }
            current.nextPage += 1
            current.hasMore = page.hasMore
            current.errorMessage = nil
            content[kind] = current
        } catch {
            guard activeRequest == request, !Task.isCancelled else { return }
            current.errorMessage = error.localizedDescription
            content[kind] = current
        }
    }

    private func displayableItems(_ items: [Item], for kind: HNUpvoteKind) -> [Item] {
        items.filter { item in
            guard item.deleted != true, item.dead != true else { return false }

            switch kind {
            case .submissions:
                return item.type != .comment
                    && !(item.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            case .comments:
                return item.type == .comment
                    && !(item.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
        }
    }
}

struct HNCommentContextView: View {
    let comment: Item

    @State private var story: Item?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var retryRequest = 0

    private let service: NewsService

    init(comment: Item, service: NewsService = .shared) {
        self.comment = comment
        self.service = service
    }

    var body: some View {
        Group {
            if let story {
                StoryDetail(item: story)
            } else if isLoading || errorMessage == nil {
                ProgressView("Loading context…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn’t load context", systemImage: "bubble.left.and.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") {
                        retryRequest += 1
                    }

                    Link("View on Hacker News", destination: comment.discussionURL)
                }
            }
        }
        .background(PlatformColors.textBackground)
        .navigationTitle("Context")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let story {
                Link(destination: story.articleURL ?? story.discussionURL) {
                    Label(
                        story.articleURL == nil ? "View on HN" : "Open Article",
                        systemImage: "arrow.up.right"
                    )
                }
                .clickableCursor()
            }
        }
        .task(id: retryRequest) {
            await loadContext()
        }
    }

    @MainActor
    private func loadContext() async {
        guard story == nil, !isLoading, !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            story = try await service.storyContext(for: comment)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
    @MainActor
    private struct HNProfileMockCanvas: View {
        @State private var appState = PreviewData.appState()

        private let account = HNAuthenticatedAccount(username: "mattrighetti")
        private let user = User(
            id: "mattrighetti",
            created: 1_480_896_000,
            karma: 2_847,
            about: "iOS developer, reader, and occasional Hacker News commenter.",
            submitted: Array(1...86)
        )

        var body: some View {
            #if os(iOS)
                IOSHomeView(
                    initialRows: PreviewData.rows,
                    loadsAutomatically: false,
                    previewComments: PreviewData.rootComments,
                    previewThreads: PreviewData.threads,
                    initialTab: .profile,
                    profileAccount: account,
                    profileUser: user
                )
                .environment(appState)
            #else
                NavigationStack {
                    HNAccountView(
                        account: account,
                        previewUser: user,
                        loadsAutomatically: false
                    )
                }
                .environment(appState)
                .frame(minWidth: 440, minHeight: 620)
            #endif
        }
    }

    #Preview("Account · Signed Out") {
        NavigationStack {
            HNAccountView(loadsAutomatically: false)
        }
        .environment(PreviewData.appState())
    }

    #Preview("Profile · Mock") {
        HNProfileMockCanvas()
    }

    #Preview("Upvotes · Mock") {
        NavigationStack {
            HNUpvotedItemsView(
                username: "mattrighetti",
                initialSubmissions: PreviewData.stories,
                initialComments: PreviewData.comments,
                loadsAutomatically: false
            )
        }
        .environment(PreviewData.appState())
    }
#endif
