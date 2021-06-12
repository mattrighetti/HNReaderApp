//
//  AppState.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Combine

class AppState: ObservableObject {
    @Published var sidebarSelection: String? = SidebarSelection.top.rawValue

    // Sidebar categories abstraction
    enum SidebarSelection: String, Equatable, CaseIterable {
        case top = "Top"
        case saved = "Saved"
        case job = "Job"
        case past = "Past"
        case comment = "Comments"
        
        var iconName: String {
            switch self {
            case .top: return "flame"
            case .saved: return "bookmark"
            case .job: return "briefcase"
            case .past: return "clock"
            case .comment: return "text.bubble"
            }
        }
    }
}
