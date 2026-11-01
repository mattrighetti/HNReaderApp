import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ItemListViewModel()
    @State private var selectedID: Int?
    @State private var searchText = ""
    @State private var unreadOnly = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var selection: AppState.SidebarSelection { appState.sidebarSelection ?? .top }
    private var source: [Item] { selection == .saved ? appState.savedItems : viewModel.stories }
    private var selectedItem: Item? {
        (source + appState.savedItems).first { $0.id == selectedID }
    }
    private var visibleItems: [Item] {
        source.filter { item in
            (!unreadOnly || !appState.readIDs.contains(item.id) || item.id == selectedID) &&
            (searchText.isEmpty || [item.title, item.by, item.urlHost].compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 260)
        } content: {
            ItemList(items: visibleItems, selectedID: $selectedID,
                     title: selection.rawValue, subtitle: selection.subtitle,
                     isLoading: selection != .saved && viewModel.isLoading,
                     errorMessage: selection == .saved ? nil : viewModel.errorMessage,
                     hasMore: selection != .saved && viewModel.hasMore,
                     isSaved: selection == .saved, isSearching: !searchText.isEmpty,
                     unreadOnly: $unreadOnly,
                     refresh: refresh, loadMore: { await viewModel.loadMore() })
                .navigationSplitViewColumnWidth(min: 520, ideal: 560, max: 720)
                .searchable(text: $searchText, prompt: "Search loaded stories")
        } detail: {
            if let item = selectedItem {
                StoryDetail(item: item).id(item.id)
            } else {
                ContentUnavailableView {
                    Label("A little curiosity goes a long way", systemImage: "text.book.closed")
                } description: {
                    Text("Choose a story to explore the conversation.")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task(id: selection) {
            selectedID = nil
            searchText = ""
            if let category = selection.category { await viewModel.load(category) }
        }
        .onChange(of: selectedID) { _, _ in
            if let item = selectedItem { appState.markRead(item) }
        }
    }

    private func refresh() async {
        if let category = selection.category { await viewModel.load(category) }
    }
}

struct Sidebar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Y")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hacker News").font(.headline)
                    Text("Stay curious.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            List(selection: $appState.sidebarSelection) {
                Section("Discover") {
                    ForEach(AppState.SidebarSelection.allCases.filter { $0 != .saved }) { section in
                        Label(section.rawValue, systemImage: section.iconName).tag(section)
                            .padding(.vertical, 4)
                    }
                }
                Section("Library") {
                    HStack {
                        Label("Saved", systemImage: "bookmark")
                        Spacer()
                        Text("\(appState.savedItems.count)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(AppState.SidebarSelection.saved)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            HStack {
                Text("Made for curious minds").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help("Settings")
            }
            .padding(16)
        }
        .navigationTitle("HNReader")
    }
}

#Preview {
    HomeView().environmentObject(AppState())
}
