import SwiftUI

enum StoryRowLayout {
    static let minimumHeight: CGFloat = 64
}

/// Decode comment HTML into an excerpt that each platform can style independently.
struct ItemRowTitle: View {
    let item: Item

    @State private var commentPreview = ""

    var body: some View {
        Text(item.type == .comment ? commentPreview : item.title ?? "Untitled story")
            .task(id: item.text) {
                guard item.type == .comment, !Task.isCancelled else { return }
                let rendered = await HTMLText.renderNative(item.text ?? "Comment text unavailable.")
                guard !Task.isCancelled else { return }
                commentPreview = rendered.string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            }
    }
}

struct ItemCell: View {
    let item: Item
    let rank: Int
    var isSelected = false

    @Environment(AppState.self) private var appState

    private var isRead: Bool {
        appState.readIDs.contains(item.id)
    }

    private var titleColor: Color {
        if isSelected {
            return .white
        }

        return isRead ? .secondary : .primary
    }

    private var secondaryColor: Color {
        isSelected ? Color.white.opacity(0.8) : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Group {
                    if item.type == .comment {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 12, weight: .medium))
                            .accessibilityHidden(true)
                    } else {
                        Text("\(rank).")
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                    }
                }
                .foregroundStyle(isSelected ? Color.white.opacity(0.55) : Color.secondary)

                Text(
                    item.type == .comment
                        ? "Comment by \(item.by ?? "Deleted user")"
                        : item.urlHost ?? "news.ycombinator.com"
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? Color.white.opacity(0.75)
                        : item.type == .comment ? Color.secondary : Color.accentColor
                )
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

                if appState.isSaved(item) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        .accessibilityLabel("Saved")
                }
            }

            ItemRowTitle(item: item)
                .font(
                    item.type == .comment
                        ? .system(size: 15)
                        : .system(size: 17, weight: .semibold, design: .rounded)
                )
                .lineSpacing(1)
                .lineLimit(3)
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                if item.type != .comment, let author = item.by {
                    Text(author)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                        .help("Posted by \(author)")

                    Text("·")
                        .accessibilityHidden(true)
                }

                Text(item.timeStringRepresentation.map { "\($0) ago" } ?? "")
                    .lineLimit(1)
                    .fixedSize()

                Spacer(minLength: 6)
            }
            .font(.system(size: 14))
            .foregroundStyle(secondaryColor)

            HStack(spacing: 14) {
                if item.type != .comment {
                    metadataValue("\(item.score ?? 0)", systemImage: "arrow.up")
                }
                metadataValue(
                    "\(item.type == .comment ? item.kids?.count ?? 0 : item.descendants ?? 0)",
                    systemImage: "bubble.left"
                )
            }
            .font(.system(size: 14))
            .foregroundStyle(secondaryColor)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .clickableCursor()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            item.type == .comment ? "savedComment.\(item.id)" : "story.\(item.id)"
        )
        .contextMenu {
            Button(
                appState.isSaved(item) ? "Remove from Saved" : "Save for Later",
                systemImage: "bookmark"
            ) {
                appState.toggleSaved(item)
            }

            if item.type != .comment {
                Link("Open Article", destination: item.articleURL ?? item.discussionURL)
            }

            Link("Open Discussion", destination: item.discussionURL)

            ShareLink(item: item.articleURL ?? item.discussionURL)
        }
    }

    private func metadataValue(_ value: String, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.65) : Color.secondary.opacity(0.8))

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .fixedSize()
    }
}

#if DEBUG && os(macOS)
struct CompactStoryPreview: View {
    @State private var appState: AppState

    private let items: [Item]
    private let selectedID: Int?

    init(selectedID: Int? = nil, includesComment: Bool = false) {
        self.selectedID = selectedID

        items = includesComment
            ? Array(PreviewData.comments.prefix(1)) + Array(PreviewData.stories.prefix(2))
            : PreviewData.stories
        let state = PreviewData.appState()
        if includesComment, let comment = PreviewData.comments.first {
            state.toggleSaved(comment)
            state.markRead(comment)
        }
        _appState = State(initialValue: state)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(StoryRow.savedRows(for: items)) { row in
                ItemCell(item: row.item, rank: row.rank, isSelected: row.id == selectedID)
                    .frame(minHeight: StoryRowLayout.minimumHeight)
                    .background(row.id == selectedID ? Color.accentColor : Color.clear)
            }
        }
        .padding(.horizontal, 12)
        .background(PlatformColors.controlBackground)
        .environment(appState)
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

#Preview("Compact stories · Narrow", traits: .fixedLayout(width: 312, height: 240)) {
    CompactStoryPreview()
        .preferredColorScheme(.dark)
}

#Preview("Compact stories · Selected", traits: .fixedLayout(width: 520, height: 240)) {
    CompactStoryPreview(selectedID: 1)
        .preferredColorScheme(.dark)
}

#Preview("Compact stories · Wide", traits: .fixedLayout(width: 1200, height: 220)) {
    CompactStoryPreview()
        .preferredColorScheme(.dark)
}

#Preview("Saved stories and comments · Dark", traits: .fixedLayout(width: 520, height: 280)) {
    CompactStoryPreview(includesComment: true)
        .preferredColorScheme(.dark)
}

#Preview("Saved stories and comments · Light", traits: .fixedLayout(width: 520, height: 280)) {
    CompactStoryPreview(includesComment: true)
        .preferredColorScheme(.light)
}

#Preview("Saved comment · Selected", traits: .fixedLayout(width: 312, height: 280)) {
    CompactStoryPreview(selectedID: PreviewData.comments.first?.id, includesComment: true)
        .preferredColorScheme(.dark)
}
#endif
