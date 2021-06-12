//
//  HomeView.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import CoreData

struct HomeView: View {
    var body: some View {
        NavigationView {
            Sidebar()
            ItemList()
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(selection: $appState.sidebarSelection) {
            Section(header: Text("Categories")) {
                ForEach(AppState.SidebarSelection.allCases, id: \.self) { selectionItem in
                    Label(selectionItem.rawValue, systemImage: selectionItem.iconName)
                        .tag(selectionItem.rawValue)
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
