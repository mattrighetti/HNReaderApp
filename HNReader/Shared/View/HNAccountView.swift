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
            showsMacDismissButton: false
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
#endif
