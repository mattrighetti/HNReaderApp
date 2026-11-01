import SwiftUI

enum StoryRowLayout {
    static let height: CGFloat = 80
}

struct ItemCell: View {
    let item: Item
    let rank: Int

    @EnvironmentObject private var appState: AppState

    private var isRead: Bool {
        appState.readIDs.contains(item.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 26, height: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 4, height: 4)
                        .frame(width: 6, height: 18)
                        .opacity(isRead ? 0 : 1)
                        .accessibilityLabel("Unread")
                        .accessibilityHidden(isRead)

                    Text(item.title ?? "Untitled story")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .lineSpacing(1)
                        .lineLimit(2)
                        .foregroundStyle(isRead ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if appState.isSaved(item) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .frame(height: 18)
                    }
                }

                HStack(spacing: 12) {
                    Text(item.urlHost ?? "news.ycombinator.com")
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 0)

                    if let author = item.by {
                        Text("by \(author)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .layoutPriority(1)
                            .help("Posted by \(author)")
                    }

                    Label("\(item.score ?? 0)", systemImage: "arrowtriangle.up")
                        .fixedSize()

                    Label("\(item.descendants ?? 0)", systemImage: "bubble.right")
                        .fixedSize()

                    Text(item.timeStringRepresentation.map { "\($0) ago" } ?? "")
                        .fixedSize()
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(
                appState.isSaved(item) ? "Remove from Saved" : "Save for Later",
                systemImage: "bookmark"
            ) {
                appState.toggleSaved(item)
            }

            Link("Open Article", destination: item.articleURL ?? item.discussionURL)

            Link("Open Discussion", destination: item.discussionURL)

            ShareLink(item: item.articleURL ?? item.discussionURL)
        }
    }
}

#if DEBUG
struct CompactStoryPreview: View {
    @StateObject private var appState: AppState

    private let items: [Item]

    init() {
        let posted = Int(Date().addingTimeInterval(-7200).timeIntervalSince1970)
        let examples = """
        [
            {
                "id": 1,
                "by": "movq",
                "title": "Novellas with Groff",
                "url": "https://movq.de",
                "score": 34,
                "descendants": 9,
                "time": \(posted)
            },
            {
                "id": 2,
                "by": "ninchi",
                "title": "Work, Art, and Study: AI and Ownership",
                "url": "https://ninchi.substack.com",
                "score": 128,
                "descendants": 42,
                "time": \(posted)
            },
            {
                "id": 3,
                "by": "compilerfan",
                "title": "A surprisingly small compiler, built from first principles and a little curiosity",
                "url": "https://example.com",
                "score": 256,
                "descendants": 61,
                "time": \(posted)
            }
        ]
        """

        items = (try? JSONDecoder().decode([Item].self, from: Data(examples.utf8))) ?? []

        let defaults = UserDefaults(suiteName: "HNReader.CompactStoryPreview")!
        defaults.removePersistentDomain(forName: "HNReader.CompactStoryPreview")

        let state = AppState(defaults: defaults)

        if let last = items.last {
            state.markRead(last)
        }

        if let second = items.dropFirst().first {
            state.toggleSaved(second)
        }

        defaults.removePersistentDomain(forName: "HNReader.CompactStoryPreview")
        _appState = StateObject(wrappedValue: state)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemCell(item: item, rank: index + 1)
                    .frame(height: StoryRowLayout.height)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(.primary.opacity(0.09))
                            .frame(height: 1)
                    }
            }
        }
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .environmentObject(appState)
    }
}

#Preview("Compact stories · Light", traits: .fixedLayout(width: 520, height: 240)) {
    CompactStoryPreview()
        .preferredColorScheme(.light)
}

#Preview("Compact stories · Dark", traits: .fixedLayout(width: 520, height: 240)) {
    CompactStoryPreview()
        .preferredColorScheme(.dark)
}

#Preview("Compact stories · Narrow", traits: .fixedLayout(width: 420, height: 240)) {
    CompactStoryPreview()
        .preferredColorScheme(.dark)
}
#endif
