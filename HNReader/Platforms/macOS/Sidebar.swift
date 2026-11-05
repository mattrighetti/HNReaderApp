import SwiftUI

struct Sidebar: View {
    @Binding var selection: AppState.SidebarSelection?
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

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

            List(selection: $selection) {
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

                #if os(macOS)
                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .clickableCursor()
                    .buttonStyle(.plain)
                    .help("Settings")
                #endif
            }
            .padding(16)
        }
        .navigationTitle("HNReader")
    }
}
