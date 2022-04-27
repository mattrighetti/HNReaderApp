//
//  AppState.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Combine
import HackerNews
import SwiftUI

class AppState: ObservableObject {
    @AppStorage("displayMode") var displayMode: DisplayMode = .dark
    @Published var sidebarSelection: SidebarSelection? = SidebarSelection.top {
        willSet {
            switch newValue {
            case .top:
                newsSelection = .top
            case .ask:
                newsSelection = .ask
            case .show:
                newsSelection = .show
            case .best:
                newsSelection = .best
            case .new:
                newsSelection = .new
            case .job:
                newsSelection = .job
            default:
                break
            }
        }
    }

    @Published var newsSelection: HackerNews.API.Stories = .top

    func getColorScheme() -> ColorScheme {
        switch displayMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return .dark
        }
    }

    func setColorScheme(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            displayMode = .dark
        case .light:
            displayMode = .light
        @unknown default:
            break
        }
    }

    // Sidebar categories abstraction
    enum SidebarSelection: String, Equatable, CaseIterable {
        case top = "Top"
        case ask = "Ask"
        case show = "Show"
        case job = "Job"
        case best = "Best"
        case new = "Newest"

        var iconName: String {
            switch self {
            case .top: return "flame"
            case .ask: return "person.fill.questionmark"
            case .new: return "paperplane"
            case .show: return "eye.circle"
            case .best: return "rosette"
            case .job: return "briefcase"
            }
        }
    }

    enum DisplayMode: Int {
        case system = 0
        case dark = 1
        case light = 2
    }
}
