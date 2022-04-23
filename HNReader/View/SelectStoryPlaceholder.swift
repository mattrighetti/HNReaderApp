//
//  SelectStoryPlaceholder.swift
//  HNReader
//
//  Created by Mattia Righetti on 4/21/22.
//

import SwiftUI

struct SelectStoryPlaceholderImage: View {
    var body: some View {
        VStack {
            Image("Select")
                .resizable()
                .frame(width: 400, height: 400, alignment: .center)
        }
    }
}
