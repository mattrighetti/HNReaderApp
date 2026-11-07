import SwiftUI

/// The iOS feed uses the shared row so saved, upvoted, and macOS lists stay aligned.
struct IOSStoryRow: View {
    let row: StoryRow

    var body: some View {
        ItemCell(item: row.item, rank: row.rank)
    }
}
