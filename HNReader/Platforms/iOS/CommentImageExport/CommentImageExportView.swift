import SwiftUI

struct CommentImageExportView: View {
    let snapshot: CommentImageSnapshot

    @Environment(\.dismiss) private var dismiss
    @State private var style = CommentImageStyle()
    @State private var formatted: NSAttributedString?
    @State private var output: CommentImageRenderer.Output?
    @State private var renderedStyle: CommentImageStyle?
    @State private var failure: CommentImageRenderer.Failure?
    @State private var retry = 0
    @State private var shareFile: CommentImageShareFile?
    @State private var shareError: String?
    @State private var resolvedArticleTitle: String?

    private struct Request: Equatable {
        let style: CommentImageStyle
        let retry: Int
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Appearance") {
                    Picker("Background", selection: $style.palette) {
                        ForEach(CommentImageStyle.Palette.allCases) { palette in
                            Text(palette.rawValue).tag(palette)
                        }
                    }
                    .accessibilityIdentifier("comment.image.background")
                    Toggle("HNReader watermark", isOn: $style.watermark)
                }

                Section("Content") {
                    Toggle("Include username", isOn: $style.includeUsername)
                    Toggle("Include article title", isOn: $style.includeArticleTitle)
                }

                Section {
                    ShareLink("Share Comment Link", item: snapshot.url)
                } footer: {
                    Text("Choose which details to include. Hacker News attribution stays visible.")
                }
            }
            .navigationTitle("Comment Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share Image", systemImage: "square.and.arrow.up") { share() }
                        .disabled(output == nil || renderedStyle != style || failure != nil)
                }
            }
            .task(id: Request(style: style, retry: retry)) { await render() }
            .sheet(item: $shareFile) { file in
                CommentImageShareSheet(file: file)
            }
            .alert("Unable to Share Image", isPresented: Binding(
                get: { shareError != nil }, set: { if !$0 { shareError = nil } }
            )) {
                Button("OK", role: .cancel) { shareError = nil }
            } message: { Text(shareError ?? "") }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let failure {
            ContentUnavailableView {
                Label("Image Unavailable", systemImage: "photo")
            } description: {
                Text(failure.localizedDescription)
            } actions: {
                if failure == .encoding || failure == .articleTitleUnavailable {
                    Button("Try Again") { retry += 1 }
                }
            }
        } else if let output {
            Image(uiImage: output.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if renderedStyle != style {
                        ProgressView()
                            .accessibilityLabel(loadingLabel)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                .accessibilityLabel(previewAccessibilityLabel)
                .accessibilityIdentifier("comment.image.preview")
        } else {
            ProgressView(loadingLabel)
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private var loadingLabel: String {
        style.includeArticleTitle && snapshot.articleTitle == nil && resolvedArticleTitle == nil
            ? "Loading article title…" : "Creating preview…"
    }

    private var previewAccessibilityLabel: String {
        var parts = ["Hacker News comment"]
        if renderedStyle?.includeArticleTitle == true,
            let title = resolvedArticleTitle ?? snapshot.articleTitle {
            parts.append(title)
        }
        if renderedStyle?.includeUsername == true { parts.append("By \(snapshot.author)") }
        if let output { parts.append(output.text) }
        return parts.joined(separator: ". ")
    }

    @MainActor
    private func render() async {
        let requestedStyle = style
        failure = nil
        do {
            try await Task.sleep(for: .milliseconds(200))
            var title = resolvedArticleTitle ?? snapshot.articleTitle
            if requestedStyle.includeArticleTitle, title == nil {
                guard let comment = snapshot.sourceComment else {
                    throw CommentImageRenderer.Failure.articleTitleUnavailable
                }
                do {
                    let story = try await NewsService.shared.storyContext(for: comment)
                    try Task.checkCancellation()
                    guard let loadedTitle = CommentImageSnapshot.normalizedTitle(story.title) else {
                        throw CommentImageRenderer.Failure.articleTitleUnavailable
                    }
                    title = loadedTitle
                    resolvedArticleTitle = loadedTitle
                } catch {
                    try Task.checkCancellation()
                    throw CommentImageRenderer.Failure.articleTitleUnavailable
                }
            }
            let text: NSAttributedString
            if let formatted {
                text = formatted
            } else {
                text = try await CommentImageRenderer.format(snapshot)
                try Task.checkCancellation()
                formatted = text
            }
            try Task.checkCancellation()
            let result = try CommentImageRenderer.render(
                snapshot: snapshot, formatted: text, style: requestedStyle, articleTitle: title)
            try Task.checkCancellation()
            output = result
            renderedStyle = requestedStyle
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            output = nil
            failure = error as? CommentImageRenderer.Failure ?? .encoding
        }
    }

    private func share() {
        guard let output, renderedStyle == style else { return }
        do {
            shareFile = try CommentImageShareFile(png: output.png, commentID: snapshot.id)
        } catch {
            shareError = "The image could not be prepared for sharing. Please try again."
        }
    }
}

#Preview("Comment image · Rich text") {
    CommentImageExportView(snapshot: CommentImageSnapshot(
        id: 8863, author: "dhouston",
        html: """
            <p>The best tools make sharing an idea feel effortless.</p>
            <p>&gt; Make something people want.</p>
            <p>Keep <i>the context</i>, credit the author, and link to the
            <a href="https://news.ycombinator.com">conversation</a>.</p>
            <pre><code>let idea = "Share the conversation"</code></pre>
            """, articleTitle: "My YC app: Dropbox — Throw away your USB drive"
    ))
}

#Preview("Comment image · Too long") {
    CommentImageExportView(snapshot: CommentImageSnapshot(
        id: 8863, author: "reader", html: String(repeating: "<p>A longer conversation.</p>", count: 100)
    ))
}

#if DEBUG
    /// Local fixtures for exercising the real long-press and sharing flow without
    /// network requests or changing the user's saved items.
    struct CommentImageExportTestScene: View {
        @State private var appState = PreviewData.appState(includeSavedStories: false)

        private var comment: Item {
            let long = ProcessInfo.processInfo.arguments.contains("--comment-image-long")
            let text = long ? String(repeating: "<p>A longer conversation.</p>", count: 100)
                : "<p>A thoughtful comment worth sharing.</p><p>&gt; Keep the context.</p><p>Credit <i>the author</i>.</p>"
            let data = try! JSONSerialization.data(withJSONObject: [
                "id": 8863, "type": "comment", "by": "fixture_author", "text": text, "kids": [8864],
            ])
            return try! JSONDecoder().decode(Item.self, from: data)
        }

        private var reply: Item {
            try! JSONDecoder().decode(Item.self, from: Data(#"{"id":8864,"type":"comment","by":"fixture_reply","text":"<p>A reply worth sharing too.</p>"}"#.utf8))
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    CommentView(
                        item: comment, storyTitle: "Building tools people want",
                        previewThreads: [8863: [reply]], expandPreview: true)
                        .padding()
                }
                .navigationTitle("Comment fixture")
            }
            .environment(appState)
        }
    }
#endif

#if DEBUG
/// An editable SwiftUI mock of the exported image, for exploring its design in
/// Canvas. The actual PNG is still drawn by CommentImageRenderer.
///
/// Edit the layout below and the sample blocks to try typography, spacing, and
/// attribution treatments without opening the export sheet or running the app.
private struct CommentImageCardMock: View {
    var style = CommentImageStyle()
    var author = "dhouston"
    var articleTitle: String? = "My YC app: Dropbox — Throw away your USB drive"
    var width: CGFloat? = 360
    var blocks: [Block] = Self.sampleComment

    enum Block {
        case paragraph(String)
        case quote(String)
        case code(String)
    }

    private var ink: Color { Color(uiColor: style.ink) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("HACKER NEWS")
                    .font(.system(size: 10, weight: .bold))

                if style.includeArticleTitle, let articleTitle {
                    Text(articleTitle)
                        .font(.system(size: 16, weight: .semibold))
                }

                if style.includeUsername {
                    Text(author)
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        commentBlock(block)
                    }
                }
                .font(.system(size: 16))
                .lineSpacing(5)

                if style.watermark {
                    HStack(spacing: 8) {
                        Image(CommentImageStyle.logoAssetName)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("Shared with HNReader")
                            .font(.system(size: 11))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .frame(width: width)
        .foregroundStyle(ink)
        .background(Color(uiColor: style.palette.background))
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func commentBlock(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            Text(LocalizedStringKey(text))
                .tint(ink)
        case .quote(let text):
            Text(text)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ink.opacity(0.7))
                        .frame(width: 3)
                        .padding(.vertical, 1)
                }
        case .code(let text):
            Text(text)
                .font(.system(size: 14, design: .monospaced))
        }
    }

    static let sampleComment: [Block] = [
        .paragraph("The best tools make sharing an idea feel effortless."),
        .quote("Make something people want."),
        .paragraph("Keep *the context* and credit the author."),
        .code("let idea = \"Share the conversation\""),
    ]

    static let longComment: [Block] = [
        .paragraph("The most useful software often starts with a small observation: something you do every day takes more effort than it should."),
        .quote("You don’t need to solve the whole problem at once. Make one part of it noticeably better."),
        .paragraph("I’ve found that the hard part is deciding what to leave out. A clear interface gives the idea room to breathe, and makes the next step obvious."),
        .paragraph("That applies to sharing a comment too. Preserve the author’s words, keep enough context to understand them, and give people a way back to the conversation."),
    ]
}

#Preview("Card mock · Paper", traits: .sizeThatFitsLayout) {
    CommentImageCardMock()
}

#Preview("Card mock · Midnight", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(style: CommentImageStyle(palette: .midnight))
}

#Preview("Card mock · Forest", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(style: CommentImageStyle(palette: .forest))
}

#Preview("Card mock · Plum", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(style: CommentImageStyle(palette: .plum))
}

#Preview("Card mock · Short, no watermark", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(
        style: CommentImageStyle(watermark: false), author: "dang",
        blocks: [.paragraph("The best interfaces give the conversation room to breathe.")]
    )
}

#Preview("Card mock · Long comment", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(author: "todsacerdoti", blocks: CommentImageCardMock.longComment)
}

#Preview("Card mock · Article title, no username", traits: .sizeThatFitsLayout) {
    CommentImageCardMock(style: CommentImageStyle(includeUsername: false, includeArticleTitle: true))
}

/// Editable Canvas mock of the app's image-sharing sheet. Appearance controls
/// update the SwiftUI card immediately; share buttons are placeholders.
private struct CommentImageShareSheetMock: View {
    var author = "dhouston"
    var articleTitle: String?
    var blocks = CommentImageCardMock.sampleComment

    @Environment(\.dismiss) private var dismiss
    @State private var style: CommentImageStyle

    init(
        style: CommentImageStyle = .init(),
        author: String = "dhouston",
        articleTitle: String? = "My YC app: Dropbox — Throw away your USB drive",
        blocks: [CommentImageCardMock.Block] = CommentImageCardMock.sampleComment
    ) {
        self.author = author
        self.articleTitle = articleTitle
        self.blocks = blocks
        _style = State(initialValue: style)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CommentImageCardMock(
                        style: style, author: author, articleTitle: articleTitle, width: nil, blocks: blocks)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Appearance") {
                    Picker("Background", selection: $style.palette) {
                        ForEach(CommentImageStyle.Palette.allCases) { palette in
                            Text(palette.rawValue).tag(palette)
                        }
                    }

                    Toggle("HNReader watermark", isOn: $style.watermark)
                }

                Section("Content") {
                    Toggle("Include username", isOn: $style.includeUsername)
                    Toggle("Include article title", isOn: $style.includeArticleTitle)
                        .disabled(articleTitle == nil)
                }

                Section {
                    Button {} label: {
                        Label("Share Comment Link", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Choose which details to include. Hacker News attribution stays visible.")
                }
            }
            .navigationTitle("Comment Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share Image", systemImage: "square.and.arrow.up") {}
                }
            }
        }
    }
}

private struct CommentImageShareSheetMockHost: View {
    @State private var showsSheet = true

    var body: some View {
        NavigationStack {
            Button("Preview Comment Image") { showsSheet = true }
                .navigationTitle("Discussion")
        }
        .sheet(isPresented: $showsSheet) {
            CommentImageShareSheetMock()
        }
    }
}

#Preview("Share sheet mock · Light") {
    CommentImageShareSheetMock()
}

#Preview("Share sheet mock · Dark") {
    CommentImageShareSheetMock(style: CommentImageStyle(palette: .midnight))
        .preferredColorScheme(.dark)
}

#Preview("Share sheet mock · Long comment") {
    CommentImageShareSheetMock(author: "todsacerdoti", blocks: CommentImageCardMock.longComment)
}

#Preview("Share sheet mock · Article title, no username") {
    CommentImageShareSheetMock(style: CommentImageStyle(includeUsername: false, includeArticleTitle: true))
}

#Preview("Share sheet mock · Presented sheet") {
    CommentImageShareSheetMockHost()
}
#endif
