import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var viewModel: ItemListViewModel

    @State private var selectedID: Int?
    @State private var searchText = ""
    @State private var unreadOnly = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private let loadsAutomatically: Bool
    private let previewComments: [Item]?
    private let previewThreads: [Int: [Item]]?

    init(
        viewModel: ItemListViewModel? = nil,
        selectedID: Int? = nil,
        loadsAutomatically: Bool = true,
        previewComments: [Item]? = nil,
        previewThreads: [Int: [Item]]? = nil
    ) {
        _viewModel = State(initialValue: viewModel ?? ItemListViewModel())
        _selectedID = State(initialValue: selectedID)
        self.loadsAutomatically = loadsAutomatically
        self.previewComments = previewComments
        self.previewThreads = previewThreads
    }

    private var selection: AppState.SidebarSelection {
        appState.sidebarSelection ?? .top
    }

    private var source: [Item] {
        selection == .saved ? appState.savedItems : viewModel.stories
    }

    private var selectedItem: Item? {
        (source + appState.savedItems).first { $0.id == selectedID }
    }

    private var visibleRows: [StoryRow] {
        let rows = selection == .saved
            ? appState.savedItems.enumerated().map {
                StoryRow(
                    rank: $0.offset + 1,
                    item: $0.element
                )
            }
            : viewModel.rows

        return rows.filter { row in
            (!unreadOnly || !appState.readIDs.contains(row.id) || row.id == selectedID)
                && (
                    searchText.isEmpty
                        || [row.item.title, row.item.by, row.item.urlHost]
                        .compactMap { $0 }
                        .contains { $0.localizedCaseInsensitiveContains(searchText)
                    }
                )
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 260)
        } content: {
            ItemList(
                rows: visibleRows,
                revision: viewModel.revision,
                selectedID: $selectedID,
                title: selection.rawValue,
                subtitle: selection.subtitle,
                isLoading: selection != .saved && viewModel.isLoading,
                isLoadingMore: selection != .saved && viewModel.isLoadingMore,
                hasMore: selection != .saved && viewModel.hasMore,
                paginationError: selection == .saved ? nil : viewModel.paginationError,
                errorMessage: selection == .saved ? nil : viewModel.errorMessage,
                isSaved: selection == .saved,
                isSearching: !searchText.isEmpty,
                unreadOnly: $unreadOnly,
                refresh: refresh,
                loadMore: {
                    if loadsAutomatically {
                        await viewModel.loadMore()
                    }
                }
            )
            .frame(minWidth: 312)
            .navigationSplitViewColumnWidth(min: 200, ideal: 312, max: 720)
            .background {
                SplitColumnWidth(minimum: 200, maximum: 720)
                    .allowsHitTesting(false)
            }
            .toolbar {
                ToolbarItem {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        TextField("Search loaded stories", text: $searchText)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Search loaded stories")
                    }
                    .padding(.horizontal, 8)
                    .frame(width: 260)
                }

                ToolbarSpacer(.fixed)
            }
        } detail: {
            if let item = selectedItem {
                StoryDetail(
                    item: item,
                    initialComments: previewComments,
                    previewThreads: previewThreads,
                    loadsAutomatically: loadsAutomatically
                )
                    .id(item.id)
            } else {
                ContentUnavailableView("Select a story", systemImage: "newspaper")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task(id: selection) {
            guard loadsAutomatically else {
                return
            }

            selectedID = nil
            searchText = ""

            if let category = selection.category {
                await viewModel.load(category)
            } else {
                viewModel.deactivate()
            }
        }
        .onChange(of: selectedItem?.id) { _, _ in
            if let item = selectedItem {
                appState.markRead(item)
            }
        }
    }

    private func refresh() async {
        guard loadsAutomatically else {
            return
        }

        if let category = selection.category {
            await viewModel.load(category, forceRefresh: true)
        }
    }
}

struct Sidebar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Y")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hacker News")
                        .font(.headline)

                    Text("Stay curious.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(18)

            List(selection: $appState.sidebarSelection) {
                Section("Discover") {
                    ForEach(AppState.SidebarSelection.allCases.filter { $0 != .saved }) { section in
                        Label(section.rawValue, systemImage: section.iconName)
                            .contentShape(Rectangle())
                            .clickableCursor()
                            .tag(section)
                            .padding(.vertical, 4)
                    }
                }

                Section("Library") {
                    HStack {
                        Label("Saved", systemImage: "bookmark")

                        Spacer()

                        Text("\(appState.savedItems.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .clickableCursor()
                    .tag(AppState.SidebarSelection.saved)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)

            HStack {
                Text("Made for curious minds")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(16)
        }
        .navigationTitle("HNReader")
    }
}

#if DEBUG
#Preview("Reader · Light", traits: .fixedLayout(width: 1600, height: 820)) {
    HomeView(
        viewModel: ItemListViewModel(previewRows: PreviewData.rows),
        selectedID: PreviewData.stories.first?.id,
        loadsAutomatically: false,
        previewComments: PreviewData.rootComments,
        previewThreads: PreviewData.threads
    )
    .environment(PreviewData.appState())
    .preferredColorScheme(.light)
    .tint(.orange)
}

#Preview("Reader · Dark", traits: .fixedLayout(width: 1600, height: 820)) {
    HomeView(
        viewModel: ItemListViewModel(previewRows: PreviewData.rows),
        selectedID: PreviewData.stories.first?.id,
        loadsAutomatically: false,
        previewComments: PreviewData.rootComments,
        previewThreads: PreviewData.threads
    )
    .environment(PreviewData.appState())
    .preferredColorScheme(.dark)
    .tint(.orange)
}

#Preview("Reader · No selection", traits: .fixedLayout(width: 1600, height: 820)) {
    HomeView(
        viewModel: ItemListViewModel(previewRows: PreviewData.rows),
        loadsAutomatically: false
    )
    .environment(PreviewData.appState())
    .tint(.orange)
}

#Preview("Sidebar", traits: .fixedLayout(width: 205, height: 600)) {
    Sidebar()
        .environment(PreviewData.appState(selection: .saved))
        .tint(.orange)
}
#endif
