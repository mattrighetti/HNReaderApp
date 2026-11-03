import SwiftUI

enum StoryRowLayout {
    static let minimumHeight: CGFloat = 64
}

struct ItemCell: View {
    let item: Item
    let rank: Int
    var isSelected = false

    @Environment(AppState.self) private var appState

    private var isRead: Bool {
        appState.readIDs.contains(item.id)
    }

    private var domainColor: Color {
        if isSelected {
            return Color.white.opacity(0.75)
        }

        return .secondary
    }

    private var titleColor: Color {
        if isSelected {
            return .white
        }

        return isRead ? .secondary : .primary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.55) : Color.secondary)
                .frame(width: 20, height: 14)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                        .frame(width: 6, height: 14)
                        .opacity(isRead ? 0 : 1)
                        .accessibilityLabel("Unread")
                        .accessibilityHidden(isRead)

                    Text(item.urlHost ?? "news.ycombinator.com")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(domainColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if appState.isSaved(item) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 14)
                    }
                }

                Text(item.title ?? "Untitled story")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineSpacing(1)
                    .lineLimit(2)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)

                HStack(spacing: 12) {
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

                    Spacer(minLength: 0)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .clickableCursor()
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

#if DEBUG && os(macOS)
struct CompactStoryPreview: View {
    @State private var appState: AppState

    private let items: [Item]
    private let selectedID: Int?

    init(selectedID: Int? = nil) {
        self.selectedID = selectedID

        items = PreviewData.stories
        _appState = State(initialValue: PreviewData.appState())
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemCell(item: item, rank: index + 1, isSelected: item.id == selectedID)
                    .frame(minHeight: StoryRowLayout.minimumHeight)
                    .background(item.id == selectedID ? Color.accentColor : Color.clear)
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
#endif
