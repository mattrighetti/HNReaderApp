//
// Created by Mattia Righetti on 12/06/21.
//

import XCTest
@testable import HNReader

class HackerNewsTests: XCTestCase {
    func testItemApiUrlStrings() throws {
        let itemUrlExpected = "https://hacker-news.firebaseio.com/v0/item/39.json"
        let itemUrl = HackerNews.API.Item.id(39)
        XCTAssertEqual(itemUrlExpected, itemUrl.urlString)
    }

    func testUserApiUrlString() throws {
        let userUrlExpected = "https://hacker-news.firebaseio.com/v0/user/randomuser.json"
        let userUrl = HackerNews.API.User.id("randomuser")
        XCTAssertEqual(userUrlExpected, userUrl.urlString)
    }

    func testStoriesApiUrlString() throws {
        XCTAssertEqual("https://hacker-news.firebaseio.com/v0/topstories.json", HackerNews.API.Stories.top.urlString)
        XCTAssertEqual("https://hacker-news.firebaseio.com/v0/newstories.json", HackerNews.API.Stories.new.urlString)
        XCTAssertEqual("https://hacker-news.firebaseio.com/v0/beststories.json", HackerNews.API.Stories.best.urlString)
        XCTAssertEqual("https://hacker-news.firebaseio.com/v0/askstories.json", HackerNews.API.Stories.ask.urlString)
        XCTAssertEqual("https://hacker-news.firebaseio.com/v0/showstories.json", HackerNews.API.Stories.show.urlString)
    }

    func testSearchURLPreservesQueryAndSelectsTheSortEndpoint() throws {
        let query = "C++ & café"
        let relevanceURL = try XCTUnwrap(HackerNews.API.Search.relevance.urlString(query: query, page: 2))
        let newestURL = try XCTUnwrap(HackerNews.API.Search.newest.urlString(query: query, page: 0))
        let components = try XCTUnwrap(URLComponents(string: relevanceURL))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "hn.algolia.com")
        XCTAssertEqual(components.path, "/api/v1/search")
        XCTAssertEqual(components.queryItems, [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "page", value: "2")
        ])
        XCTAssertTrue(relevanceURL.contains("C%2B%2B"))
        XCTAssertEqual(URLComponents(string: newestURL)?.path, "/api/v1/search_by_date")
    }
}
