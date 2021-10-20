//
//  LoadingCircle.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import SwiftUI

struct LoadingCircle: View {
    @State private var isLoading = false
 
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 10)
                .frame(width: 50, height: 50)
 
            Circle()
                .trim(from: 0, to: 0.2)
                .stroke(Color.green.opacity(0.7), style: .init(lineWidth: 7, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                .animation(
                    Animation
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false)
                )
                .onAppear() {
                    self.isLoading = true
                }
        }
        .frame(width: 70, height: 70)
    }
}

struct LoadingCircle_Previews: PreviewProvider {
    static var previews: some View {
        LoadingCircle()
    }
}
