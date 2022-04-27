//
//  Sidebar.swift
//  HNReader
//
//  Created by Mattia Righetti on 4/21/22.
//

import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.sidebarSelection) {
            Section(header: Text("Categories")) {
                ForEach(AppState.SidebarSelection.allCases, id: \.self) { selectionItem in
                    Label(selectionItem.rawValue, systemImage: selectionItem.iconName)
                        .tag(selectionItem)
                }
            }
        }
    }
}
