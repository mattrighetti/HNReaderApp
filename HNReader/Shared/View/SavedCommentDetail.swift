import SwiftUI

/// Open the saved snapshot immediately, including when the device is offline.
struct SavedCommentDetail: View {
    let item: Item
    var previewThreads: [Int: [Item]]? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CommentView(item: item, previewThreads: previewThreads)

                Link("View Comment on Hacker News", destination: item.discussionURL)
                    .clickableCursor()
                    .font(.callout)
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(PlatformColors.textBackground)
        .toolbar {
            Button(
                appState.isSaved(item) ? "Remove Comment from Saved" : "Save Comment",
                systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
            ) {
                appState.toggleSaved(item)
            }
            .clickableCursor()

            ShareLink(item: item.discussionURL)
                .clickableCursor()
        }
        .task {
            appState.markRead(item)
        }
    }
}
