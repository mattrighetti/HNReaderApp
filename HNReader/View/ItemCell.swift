import SwiftUI

struct ItemCell: View {
    let item: Item
    let rank: Int
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if !appState.readIDs.contains(item.id) {
                        Circle().fill(.orange).frame(width: 5, height: 5)
                            .accessibilityLabel("Unread")
                    }
                    Text(item.title ?? "Untitled story")
                        .font(.system(size: 15, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(appState.readIDs.contains(item.id) ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if appState.isSaved(item) {
                        Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(.orange)
                    }
                }
                Text(item.urlHost ?? "news.ycombinator.com")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label("\(item.score ?? 0)", systemImage: "arrow.up")
                        .fixedSize()
                    Label("\(item.descendants ?? 0)", systemImage: "bubble.right")
                        .fixedSize()
                    Spacer(minLength: 0)
                    Text("\(item.timeStringRepresentation ?? "") ago")
                        .fixedSize()
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(appState.isSaved(item) ? "Remove from Saved" : "Save for Later", systemImage: "bookmark") {
                appState.toggleSaved(item)
            }
            Link("Open Article", destination: item.articleURL ?? item.discussionURL)
            Link("Open Discussion", destination: item.discussionURL)
            ShareLink(item: item.articleURL ?? item.discussionURL)
        }
    }
}
