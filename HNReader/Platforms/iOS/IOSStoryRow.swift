import SwiftUI

struct IOSStoryRow: View {
    @Environment(AppState.self) private var appState

    let row: StoryRow

    private var isRead: Bool {
        appState.readIDs.contains(row.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Group {
                    if row.item.type == .comment {
                        Image(systemName: "bubble.left")
                            .font(.caption)
                            .accessibilityHidden(true)
                    } else {
                        Text("\(row.rank)")
                            .font(.caption2.monospacedDigit().weight(.medium))
                    }
                }
                .foregroundStyle(.tertiary)

                Text(
                    row.item.type == .comment
                        ? "Comment by \(row.item.by ?? "Deleted user")"
                        : row.item.urlHost ?? "news.ycombinator.com"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer(minLength: 4)

                if !isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel("Unread")
                }

                if appState.isSaved(row.item) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Saved")
                }
            }

            ItemRowTitle(item: row.item)
                .font(
                    row.item.type == .comment
                        ? .system(size: 16)
                        : .system(size: 17, weight: .semibold, design: .rounded)
                )
                .foregroundStyle(isRead ? .secondary : .primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                if row.item.type != .comment {
                    metadataValue("\(row.item.score ?? 0)", systemImage: "arrow.up")
                }
                metadataValue(
                    "\(row.item.type == .comment ? row.item.kids?.count ?? 0 : row.item.descendants ?? 0)",
                    systemImage: "bubble.left")

                if row.item.type != .comment, let author = row.item.by {
                    Text(author)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 6)

                Text(row.item.timeStringRepresentation.map { "\($0) ago" } ?? "")
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(
            row.item.type == .comment ? "savedComment.\(row.id)" : "story.\(row.id)"
        )
        .contextMenu {
            Button(
                appState.isSaved(row.item) ? "Remove from Saved" : "Save for Later",
                systemImage: "bookmark"
            ) {
                appState.toggleSaved(row.item)
            }
            if row.item.type != .comment {
                Link("Open Article", destination: row.item.articleURL ?? row.item.discussionURL)
            }
            Link("Open Discussion", destination: row.item.discussionURL)
            ShareLink(item: row.item.articleURL ?? row.item.discussionURL)
        }
    }

    private func metadataValue(_ value: String, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .fixedSize()
    }
}
