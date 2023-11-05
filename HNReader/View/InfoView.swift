//
//  InfoView.swift
//  HNReader
//
//  Created by Mattia Righetti on 05/11/23.
//

import AppKit
import StoreKit
import SwiftUI

struct InfoView: View {
    var version: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
            /// Build version of the app, i.e. `64`
        let appBundleVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String

        return "\(version) (\(appBundleVersion))"
    }

    var body: some View {
        VStack {
            Text("HNReader v\(version)")
                .font(.custom("IBMPlexSerif-SemiBold", size: 15))

            Text("This project is open source, if you like it you can star it on GitHub.")
                .lineLimit(4)
                .font(.custom("IBMPlexSerif-Regular", size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical)

            BgButton(text: "Rate HNReader", icon: "star", minSize: CGSize(width: 250, height: 50), onHover: { h in
                DispatchQueue.main.async {
                    if (h) {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }, action: {
                NSWorkspace.shared.open(URL(string: "https://apps.apple.com/it/app/id1572480416?action=write-review")!)
            })

            BgButton(text: "Open on GitHub", icon: "arrow.up.right", minSize: CGSize(width: 250, height: 50), onHover: { h in
                DispatchQueue.main.async {
                    if (h) {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }, action: {
                NSWorkspace.shared.open(URL(string: "https://github.com/mattrighetti/HNReaderApp.git")!)
            })
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    InfoView()
}
