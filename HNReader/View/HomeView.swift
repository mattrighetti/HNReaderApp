//
//  HomeView.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State var selectedItem: Int? = nil
    
    var body: some View {
        NavigationView {
            Sidebar()
            StoryList(selectedItem: $selectedItem).frame(minWidth: 400)
            SelectStoryPlaceholderImage()
        }
    }
}

struct SelectStoryPlaceholderImage: View {
    var body: some View {
        VStack {
            Image("Select")
                .resizable()
                .frame(width: 400, height: 400, alignment: .center)
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
                        .tag(selectionItem)
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
