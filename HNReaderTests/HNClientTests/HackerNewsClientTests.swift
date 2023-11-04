//
// Created by Mattia Righetti on 12/06/21.
//

import XCTest
import Combine
@testable import HNReader

class HackerNewsClientTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func testGetUser() throws {
        var user: User?
        var error: Error?
        let expectation = self.expectation(description: "userGet")

        HackerNewsClient.shared
            .getUser(withId: "mattrighetti")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let err):
                    error = err
                }
                
                expectation.fulfill()
            }, receiveValue: { usr in
                user = usr
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 5)

        XCTAssertNil(error)
        XCTAssertEqual(user!.id, "mattrighetti")
    }

    func testGetItem() throws {
        var item: Item?
        var error: Error?
        let expectation = self.expectation(description: "itemGet")

        HackerNewsClient.shared
            .getItem(withId: 27348900)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let err):
                    error = err
                }

                expectation.fulfill()
            }, receiveValue: { newItem in
                item = newItem
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 5)

        XCTAssertNil(error)
        XCTAssertNotNil(item)
        XCTAssertEqual(item!.id, 27348900)
    }

    func testGetTopStories() throws {
        var stories: [Item]?
        var error: Error?
        let expectation = self.expectation(description: "bestStoriesGet")

        HackerNewsClient.shared
            .getStories(by: .top, limit: 100)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let err):
                    error = err
                }

                expectation.fulfill()
            }, receiveValue: { items in
                stories = items
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 15)

        XCTAssertNil(error)
        XCTAssertNotNil(stories)
        print(stories)
        XCTAssertFalse(stories!.isEmpty)
    }
}
