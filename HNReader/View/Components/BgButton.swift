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

#Preview {
    BgButton(text: "Rate app", icon: "star", minSize: CGSize(width: 150, height: 50)).padding()
}
