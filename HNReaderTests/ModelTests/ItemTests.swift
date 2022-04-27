//
// Created by Mattia Righetti on 13/06/21.
//

@testable import HNReader
import XCTest

class ItemTests: XCTestCase {
    func testItemDateIntervalFormatter() {
        let yesterday = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        let item1 = Item(id: 213_412,
                         deleted: false,
                         type: .story,
                         by: nil,
                         time: Int(yesterday.timeIntervalSince1970),
                         text: nil,
                         dead: nil,
                         parent: nil,
                         poll: nil,
                         kids: nil,
                         url: "https://www.reddit.com/r/MechanicalKeyboards",
                         score: nil,
                         title: nil,
                         parts: nil,
                         descendants: nil)

        XCTAssertEqual("1d", item1.timeStringRepresentation)
        XCTAssertEqual("reddit.com", item1.urlHost)
    }
}
