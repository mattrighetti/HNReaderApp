//
//  ConditionalRedacted.swift
//  HNReader
//
//  Created by Mattia Righetti on 04/11/23.
//

import SwiftUI

struct ConditionalRedactedModifier: ViewModifier {
    var isRedacted: Bool

    func body(content: Content) -> some View {
        if isRedacted {
            content.redacted(reason: .placeholder)
        } else {
            content
        }
    }
}

extension View {
    func redactIfNull(_ obj: Optional<Any>) -> some View {
        switch obj {
        case .none:
            return self.modifier(ConditionalRedactedModifier(isRedacted: true))
        case .some(_):
            return self.modifier(ConditionalRedactedModifier(isRedacted: false))
        }
    }
}

#Preview {
    VStack {
        Text("Some Text").redactIfNull(Optional<String>.none)
    }
    .frame(width: 500, height: 500)
}
