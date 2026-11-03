//
// Created by Mattia Righetti on 13/06/21.
//

import Foundation

extension Date {
    public func timeElapsedStringRepresentation(since: Date) -> String {
        let elapsedTime = timeIntervalSince(since)
        let years = Int(floor(elapsedTime / 365 / 24 / 60 / 60))
        let days = Int(floor(elapsedTime / 24 / 60 / 60))
        let hours = Int(floor(elapsedTime / 60 / 60))
        let minutes = Int(floor(elapsedTime / 60))

        if years >= 1 {
            return "\(years)y"
        } else if days >= 1 {
            return "\(days)d"
        } else if hours >= 1 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}