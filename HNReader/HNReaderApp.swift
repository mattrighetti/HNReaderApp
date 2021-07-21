//
//  HNReaderApp.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

@main
struct HNReaderApp: App {
    let persistenceController = PersistenceController.shared
    let appState = AppState()

    private var displayModeBind: Binding<ColorScheme> {
        Binding<ColorScheme>(
            get: { appState.getColorScheme() },
            set: {
                appState.setColorScheme($0)
                displayMode = $0
            }
        )
    }
    @State var displayMode: ColorScheme?

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    displayMode = appState.getColorScheme()
                }
                .preferredColorScheme(displayMode)
                .environmentObject(appState)
        }

        Settings {
            VStack {
                Form {
                    Picker(selection: displayModeBind, label: Text("Theme")) {
                        Text("Dark").tag(ColorScheme.dark)
                        Text("Light").tag(ColorScheme.light)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 100)
                }
            }
            .frame(minWidth: 300, minHeight: 100)
            .preferredColorScheme(displayMode)
        }
    }
}
