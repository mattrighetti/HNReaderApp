import SwiftUI

struct StorySearchView: View {
    #if os(macOS)
        @Binding var selectedItem: Item?
    #else
        @Environment(AppState.self) private var appState
    #endif

    @State private var query = ""
    @State private var sort: HackerNews.API.Search = .relevance
    @State private var items: [Item] = []
    @State private var nextPage: Int?
    @State private var request: Request?
    @State private var phase: Phase = .idle

    private struct Criteria: Equatable {
        let query: String
        let sort: HackerNews.API.Search
    }

    private struct Request {
        let id = UUID()
        let criteria: Criteria
        let page: Int
    }

    private enum Phase {
        case idle, loading, loaded, failed
    }

    private var criteria: Criteria {
        Criteria(query: query.trimmingCharacters(in: .whitespacesAndNewlines), sort: sort)
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search Hacker News", text: $query)
                        .textFieldStyle(.roundedBorder)
                    if !query.isEmpty {
                        Button("Clear Search", systemImage: "xmark.circle.fill") {
                            query = ""
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding([.horizontal, .top])
            #endif

            Picker("Sort results", selection: $sort) {
                Text("Relevance").tag(HackerNews.API.Search.relevance)
                Text("Newest").tag(HackerNews.API.Search.newest)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Search")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query, placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Hacker News"
            )
        #endif
        .onChange(of: criteria) { _, criteria in
            items = []
            nextPage = nil
            #if os(macOS)
                selectedItem = nil
            #endif
            if criteria.query.isEmpty {
                request = nil
                phase = .idle
            } else {
                requestPage(0, for: criteria)
            }
        }
        .task(id: request?.id) { [request] in
            if let request, phase == .loading {
                await load(request)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if !items.isEmpty || nextPage != nil {
            #if os(macOS)
                List(selection: $selectedItem) {
                    resultRows
                }
                .listStyle(.inset)
            #else
                List {
                    resultRows
                }
                .listStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
            #endif
        } else {
            switch phase {
            case .idle:
                ContentUnavailableView("Find stories by keyword", systemImage: "magnifyingglass")
            case .loading:
                ProgressView("Searching…")
            case .loaded:
                ContentUnavailableView.search(text: criteria.query)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn’t search Hacker News", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("Try Again") {
                        requestPage(0, for: criteria)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultRows: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            #if os(macOS)
                ItemCell(item: item, rank: index + 1, isSelected: selectedItem?.id == item.id, isCompact: true)
                    .frame(minHeight: StoryRowLayout.minimumHeight)
                    .tag(item)
            #else
                NavigationLink {
                    StoryDetail(item: item)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.visible, for: .navigationBar)
                        .task { appState.markRead(item) }
                } label: {
                    IOSStoryRow(row: StoryRow(rank: index + 1, item: item))
                }
                .accessibilityIdentifier("story.\(item.id)")
            #endif
        }

        if let nextPage {
            paginationFooter(for: nextPage)
        }
    }

    private func paginationFooter(for page: Int) -> some View {
        VStack(spacing: 8) {
            if phase == .loading {
                ProgressView("Loading more stories…")
            } else if phase == .failed {
                Button("Retry Loading More") {
                    requestPage(page, for: criteria)
                }
                .buttonStyle(.borderless)
            } else {
                Text("More stories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .listRowSeparator(.hidden)
        .task { [criteria] in
            guard !Task.isCancelled, phase == .loaded, nextPage == page,
                request?.criteria == criteria, self.criteria == criteria
            else {
                return
            }
            requestPage(page, for: criteria)
        }
        .id(page)
    }

    private func requestPage(_ page: Int, for criteria: Criteria) {
        request = Request(criteria: criteria, page: page)
        phase = .loading
    }

    private func load(_ request: Request) async {
        do {
            if request.page == 0 {
                try await Task.sleep(for: .milliseconds(300))
            }
            let response = try await NewsService.shared.searchStories(
                query: request.criteria.query, sort: request.criteria.sort, page: request.page
            )
            guard !Task.isCancelled, self.request?.id == request.id, criteria == request.criteria else {
                return
            }

            var seen = Set(items.map(\.id))
            items += response.items.filter { seen.insert($0.id).inserted }
            nextPage = response.nextPage
            phase = .loaded
        } catch {
            guard !Task.isCancelled, self.request?.id == request.id, criteria == request.criteria else {
                return
            }
            phase = .failed
        }
    }
}
