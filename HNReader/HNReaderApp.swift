//
//  HNReaderApp.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import HackerNews

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
                    displayMode = .dark
                }
                .preferredColorScheme(displayMode)
                .environmentObject(appState)
        }
    }
}
