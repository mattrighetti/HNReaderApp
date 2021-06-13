//
//  AppState.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Combine

class AppState: ObservableObject {
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

    // Sidebar categories abstraction
    enum SidebarSelection: String, Equatable, CaseIterable {
        case top = "Top"
        case ask = "Ask"
        case show = "Show"
        case saved = "Saved"
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
            case .saved: return "bookmark"
            case .job: return "briefcase"
            }
        }
    }
}
