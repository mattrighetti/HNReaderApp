//
//  ContentView.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    
    @SceneStorage("categorySelection") var selection: Int = 1
    
    var body: some View {
        NavigationView {
            Sidebar(selection: $selection)
            Text("Select a category")
        }
    }
}

struct Sidebar: View {
    
    @Binding var selection: Int
    
    var body: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(SidebarSelection.allCases) { selectionItem in
                    Label(selectionItem.rawValue, systemImage: selectionItem.iconName)
                        .tag(selectionItem.id)
                }
            }
        }
    }
}

enum SidebarSelection: String, Identifiable, CaseIterable {
    case top = "Top"
    case job = "Job"
    case past = "Past"
    case comment = "Comments"
    
    var id : Int {
        switch self {
        case .top: return 1
        case .job: return 2
        case .past: return 3
        case .comment: return 4
        }
    }
    
    var iconName: String {
        switch self {
        case .top: return "flame"
        case .job: return "briefcase"
        case .past: return "clock"
        case .comment: return "text.bubble"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
