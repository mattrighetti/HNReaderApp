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
            
            StoryList(selectedItem: $selectedItem)
                .frame(minWidth: 350)
            
            SelectStoryPlaceholderImage()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
