import SwiftUI

/// A compact iOS row for stories and comments.
struct IOSStoryRow: View {
    let row: StoryRow
    @Environment(AppState.self) private var appState

    private let orange = Color(hue: 0.06, saturation: 0.88, brightness: 0.78)

    var body: some View {
        let item = row.item
        let isComment = item.type == .comment
        let timestamp = item.timeStringRepresentation ?? ""
        let replyCount = isComment ? item.kids?.count : item.descendants

        HStack(alignment: .firstTextBaseline) {
            Group {
                if isComment {
                    Image(systemName: "bubble.left")
                        .accessibilityHidden(true)
                } else {
                    Text("\(row.rank)")
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.82))

            VStack(alignment: .leading) {
                Text(
                    isComment
                        ? "Comment by \(item.by ?? "Deleted user")"
                        : item.urlHost ?? "news.ycombinator.com"
                )
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.bottom, 1)

                ItemRowTitle(item: item)
                    .font(.system(size: 15, weight: isComment ? .regular : .bold, design: .rounded))
                    .foregroundStyle(appState.readIDs.contains(item.id) ? .secondary : .primary)
                    .lineLimit(3)

                HStack(spacing: 9) {
                    if !isComment {
                        Label("\(item.score ?? 0)", systemImage: "arrow.up")
                            .foregroundStyle(orange)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left")
                        Text("\(replyCount ?? 0)")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.vertical, 1)

                    Text(isComment ? timestamp : "\(item.by ?? "unknown") · \(timestamp)")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                
            }
            
            Spacer()
            
            Image(systemName: appState.isSaved(item) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(appState.isSaved(item) ? orange : .secondary)
        }
        .contextMenu {
            Button(appState.isSaved(item) ? "Remove from Saved" : "Save for Later", systemImage: "bookmark") {
                appState.toggleSaved(item)
            }
            if !isComment {
                Link("Open Article", destination: item.articleURL ?? item.discussionURL)
            }
            Link("Open Discussion", destination: item.discussionURL)
            ShareLink(item: item.articleURL ?? item.discussionURL)
        }
    }
}

#if DEBUG
#Preview("iOS story row", traits: .fixedLayout(width: 390, height: 150)) {
    IOSStoryRow(row: PreviewData.rows[0])
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .environment(PreviewData.appState())
        .preferredColorScheme(.light)
}

#Preview("iOS story row · long title", traits: .fixedLayout(width: 390, height: 190)) {
    IOSStoryRow(row: PreviewData.rows[1])
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .environment(PreviewData.appState())
        .preferredColorScheme(.light)
}
#endif
