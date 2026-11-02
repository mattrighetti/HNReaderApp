//
//  BgButton.swift
//  HNReader
//
//  Created by Mattia Righetti on 05/11/23.
//

import SwiftUI

struct BgButton: View {
    var text: String? = nil
    var icon: String
    var disabled: Bool = false
    var minSize: CGSize
    var onHover: ((Bool) -> Void)? = nil
    var action: (() -> ())? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(Color.gray.opacity(0.1))
                .frame(width: minSize.width, height: minSize.height)

            Label(title: {
                if text != nil {
                    Text(text!)
                        .font(.custom("IBMPlexSerif-Regular", size: 13))
                }
            }, icon: {
                Image(systemName: icon)
            })
            .foregroundStyle(disabled ? .tertiary : .primary)
            .padding()
        }
        .frame(width: minSize.width, height: minSize.height)
        .onHover {
            onHover?($0)
        }
        .onTapGesture {
            action?()
        }
    }
}

#Preview("Buttons · Light") {
    VStack(spacing: 12) {
        BgButton(text: "Rate app", icon: "star", minSize: CGSize(width: 200, height: 44))

        BgButton(
            text: "Disabled action",
            icon: "arrow.up.right",
            disabled: true,
            minSize: CGSize(width: 200, height: 44)
        )
    }
    .padding(20)
    .preferredColorScheme(.light)
}

#Preview("Buttons · Dark") {
    BgButton(text: "Open on GitHub", icon: "arrow.up.right", minSize: CGSize(width: 200, height: 44))
        .padding(20)
        .preferredColorScheme(.dark)
}
