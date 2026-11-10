import SwiftUI
import UIKit

private enum AppIconChoice: String, CaseIterable, Identifiable {
    case orange = "Orange"
    case plum = "Plum"
    case midnight = "Midnight"
    case forest = "Forest"

    var id: String { rawValue }
    var alternateName: String? { self == .orange ? nil : "AppIcon\(rawValue)" }
    var previewName: String { "IconPreview\(rawValue)" }
}

struct IOSSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedName = UIApplication.shared.alternateIconName

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ArticleFontSettingsView()
                    } label: {
                        LabeledContent("Article font", value: appState.articleFont.name)
                    }
                } header: {
                    Text("Article font")
                } footer: {
                    Text("Choose the typeface used for story titles and article text, with a live preview.")
                }

                Section {
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(currentIcon.previewName)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityHidden(true)

                            LabeledContent("App icon", value: currentIcon.rawValue)
                        }
                    }
                } header: {
                    Text("App icon")
                } footer: {
                    Text("Choose how HNReader looks on your Home Screen.")
                }

                Section {
                    Link("GitHub repository", destination: AppInfo.repositoryURL)
                    LabeledContent("Version", value: AppInfo.versionDescription)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear { selectedName = UIApplication.shared.alternateIconName }
        }
    }

    private var currentIcon: AppIconChoice {
        AppIconChoice.allCases.first { $0.alternateName == selectedName } ?? .orange
    }
}

private struct AppIconSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedName = UIApplication.shared.alternateIconName
    @State private var pendingChoice: AppIconChoice?
    @State private var iconError: String?

    var body: some View {
        Form {
            Section {
                ForEach(AppIconChoice.allCases) { icon in
                    Button {
                        Task { await select(icon) }
                    } label: {
                        HStack(spacing: 16) {
                            Image(icon.previewName)
                                .resizable()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                                .accessibilityHidden(true)

                            Text(icon.rawValue)
                                .foregroundStyle(.primary)

                            Spacer()

                            if pendingChoice == icon {
                                ProgressView()
                            } else if selectedName == icon.alternateName {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .disabled(pendingChoice != nil || !UIApplication.shared.supportsAlternateIcons)
                    .accessibilityLabel("\(icon.rawValue) app icon")
                    .accessibilityAddTraits(selectedName == icon.alternateName ? .isSelected : [])
                }
            } footer: {
                Text(UIApplication.shared.supportsAlternateIcons
                     ? "Choose how HNReader looks on your Home Screen."
                     : "Changing the app icon isn’t available on this device.")
            }
        }
        .navigationTitle("App icon")
        .onAppear { selectedName = UIApplication.shared.alternateIconName }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                selectedName = UIApplication.shared.alternateIconName
            }
        }
        .alert("Couldn’t change app icon", isPresented: Binding(
            get: { iconError != nil },
            set: { if !$0 { iconError = nil } }
        )) {
            Button("OK", role: .cancel) { iconError = nil }
        } message: {
            Text(iconError ?? "Please try again.")
        }
    }

    @MainActor
    private func select(_ icon: AppIconChoice) async {
        guard pendingChoice == nil,
              UIApplication.shared.supportsAlternateIcons,
              selectedName != icon.alternateName else { return }

        pendingChoice = icon
        defer { pendingChoice = nil }

        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateName)
            selectedName = UIApplication.shared.alternateIconName
        } catch {
            iconError = error.localizedDescription
        }
    }
}
