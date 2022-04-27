//
//  HNReaderApp.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import HackerNews
import SwiftUI

@main
struct HNReaderApp: App {
    let appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
        }
    }
}
