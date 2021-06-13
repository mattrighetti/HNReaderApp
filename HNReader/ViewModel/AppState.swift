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
            case .comment:
                newsSelection = nil
            case .job:
                newsSelection = .job
            case .past:
                newsSelection = nil
            case .some(.saved):
                newsSelection = nil
            default:
                break
            }
        }
    }
    @Published var newsSelection: HackerNews.API.Stories? = nil

    // Sidebar categories abstraction
    enum SidebarSelection: String, Equatable, CaseIterable {
        case top = "Top"
        case ask = "Ask"
        case show = "Show"
        case saved = "Saved"
        case job = "Job"
        case past = "Past"
        case comment = "Comments"
        
        var iconName: String {
            switch self {
            case .top: return "flame"
            case .ask: return "person.fill.questionmark"
            case .show: return "eye.circle"
            case .saved: return "bookmark"
            case .job: return "briefcase"
            case .past: return "clock"
            case .comment: return "text.bubble"
            }
        }
    }
}
