//
//  InfoView.swift
//  HNReader
//
//  Created by Mattia Righetti on 05/11/23.
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        VStack {
            Text("HNReader v1.2")
                .font(.title2)
                .padding(.bottom)

            Text("This project is open source")

            BgButton(text: "Rate HNReader", icon: "star", minSize: CGSize(width: 200, height: 50), onHover: { h in
                DispatchQueue.main.async {
                    if (h) {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }, action: {
                NSWorkspace.shared.open(URL(string: "https://github.com/mattrighetti/HNReader.git")!)
            })

            BgButton(text: "Open on GitHub", icon: "arrow.up.right", minSize: CGSize(width: 200, height: 50), onHover: { h in
                DispatchQueue.main.async {
                    if (h) {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }, action: {
                NSWorkspace.shared.open(URL(string: "https://github.com/mattrighetti/HNReader.git")!)
            })
        }
        .padding()
        .frame(minWidth: 300)
    }
}

#Preview {
    InfoView()
}
