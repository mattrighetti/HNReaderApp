//
//  InfoView.swift
//  HNReader
//
//  Created by Mattia Righetti on 05/11/23.
//

import SwiftUI

struct InfoView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            Text("HNReader · \(AppInfo.versionDescription)")
                .font(.custom("IBMPlexSerif-SemiBold", size: 15))

            Text("This project is open source, if you like it you can star it on GitHub.")
                .lineLimit(4)
                .font(.custom("IBMPlexSerif-Regular", size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical)

            BgButton(text: "Rate HNReader", icon: "star", minSize: CGSize(width: 250, height: 50), action: {
                if let url = URL(string: "https://apps.apple.com/it/app/id1572480416?action=write-review") {
                    openURL(url)
                }
            })

            BgButton(text: "Open on GitHub", icon: "arrow.up.right", minSize: CGSize(width: 250, height: 50), action: {
                openURL(AppInfo.repositoryURL)
            })
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview("About · Light") {
    InfoView()
        .preferredColorScheme(.light)
}

#Preview("About · Dark") {
    InfoView()
        .preferredColorScheme(.dark)
}
