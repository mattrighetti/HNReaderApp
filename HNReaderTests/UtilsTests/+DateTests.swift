//
// Created by Mattia Righetti on 13/06/21.
//

@testable import HNReader
import XCTest

class DateTests: XCTestCase {
    func testElapsedTimeStringRepresentation() {
        let minuteTimeInterval = TimeInterval(60)
        let hourTimeInterval = TimeInterval(minuteTimeInterval * 60)
        let dayTimeInterval = TimeInterval(24 * hourTimeInterval)
        let yearTimeInterval = TimeInterval(dayTimeInterval * 365)
        let yesterday = Date(timeIntervalSinceNow: -dayTimeInterval)
        let halfHourAgo = Date(timeIntervalSinceNow: -(minuteTimeInterval * 30))
        let hourAgo = Date(timeIntervalSinceNow: -hourTimeInterval)
        let threeYearsAgo = Date(timeIntervalSinceNow: -(3 * yearTimeInterval))
        let s1 = Date().timeElapsedStringRepresentation(since: yesterday)
        let s2 = Date().timeElapsedStringRepresentation(since: halfHourAgo)
        let s3 = Date().timeElapsedStringRepresentation(since: hourAgo)
        let s4 = Date().timeElapsedStringRepresentation(since: threeYearsAgo)
        XCTAssertEqual("1d", s1)
        XCTAssertEqual("30m", s2)
        XCTAssertEqual("1h", s3)
        XCTAssertEqual("3y", s4)
    }
}
