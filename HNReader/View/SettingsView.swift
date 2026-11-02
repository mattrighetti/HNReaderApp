import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            appHeader

            appearance

            project

            credits

            Text(AppInfo.versionDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(appState.colorScheme)
        .tint(.orange)
    }

    private var appHeader: some View {
        HStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("HNReader")
                    .font(.system(size: 20, weight: .semibold))

                Text("Hacker News for macOS")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.system(size: 12, weight: .semibold))

            Picker("Appearance", selection: $appState.displayMode) {
                ForEach(AppState.DisplayMode.allCases, id: \.rawValue) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var project: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project")
                .font(.system(size: 12, weight: .semibold))

            Link(destination: AppInfo.repositoryURL) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub repository")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("mattrighetti/HNReaderApp")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .help("Open the HNReader repository on GitHub")
        }
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Credits")
                .font(.system(size: 12, weight: .semibold))

            VStack(spacing: 12) {
                HStack {
                    Text("Created by")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Link("Mattia Righetti", destination: AppInfo.authorURL)
                }

                HStack {
                    Text("News and discussions")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Link("Hacker News", destination: AppInfo.hackerNewsURL)
                }

                HStack {
                    Text("License")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("MIT or Apache 2.0")
                }
            }
            .font(.system(size: 11))
            .padding(14)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

#if DEBUG
#Preview("Settings · System") {
    SettingsView()
        .environmentObject(PreviewData.appState())
}

#Preview("Settings · Light") {
    SettingsView()
        .environmentObject(PreviewData.appState(theme: .light))
}

#Preview("Settings · Dark") {
    SettingsView()
        .environmentObject(PreviewData.appState(theme: .dark))
}
#endif
