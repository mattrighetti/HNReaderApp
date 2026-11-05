//
// Created by Mattia Righetti on 13/06/21.
//

import XCTest
@testable import HNReader

class ItemTests: XCTestCase {
    func testItemDateIntervalFormatter() {
        let yesterday = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        let item1 = Item(
            id: 213412,
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
            descendants: nil
        )

        XCTAssertEqual("1d", item1.timeStringRepresentation)
        XCTAssertEqual("reddit.com", item1.urlHost)
    }
}

extension ItemTests {
    private func decode(_ json: String) throws -> Item {
        try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    }

    func testMissingMetadataAndInvalidLinksAreSafe() throws {
        let item = try decode(#"{"id":1,"url":"not a web address"}"#)

        XCTAssertNil(item.urlHost)
        XCTAssertNil(item.articleURL)
        XCTAssertNil(item.timeStringRepresentation)
        XCTAssertEqual(item.discussionURL.absoluteString, "https://news.ycombinator.com/item?id=1")

        let unsafe = try decode(#"{"id":2,"url":"javascript:alert(1)"}"#)

        XCTAssertNil(unsafe.articleURL)

        let host = try decode(#"{"id":3,"url":"https://example.com/www.test"}"#)

        XCTAssertEqual(host.urlHost, "example.com")
    }

    @MainActor
    func testSavedStoriesAndReadStateSurviveRelaunch() throws {
        let suite = "HNReaderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
        }
        let item = try decode(#"{"id":42,"title":"Keep this story","kids":[43,44]}"#)
        let state = AppState(defaults: defaults)
        state.toggleSaved(item)
        state.markRead(item)
        state.markRead(item)

        let restored = AppState(defaults: defaults)

        XCTAssertEqual(restored.savedItems, [item])
        XCTAssertEqual(restored.readIDs, [42])

        restored.toggleSaved(item)

        XCTAssertTrue(AppState(defaults: defaults).savedItems.isEmpty)
        XCTAssertEqual(AppState(defaults: defaults).readIDs, [42])
    }

    @MainActor
    func testSavedCommentsPreserveTheirContentAlongsideExistingStories() throws {
        let suite = "HNReaderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // Start with the existing on-disk format so upgrades keep saved stories.
        let story = try decode(#"{"id":42,"type":"story","title":"Keep this story"}"#)
        defaults.set(try JSONEncoder().encode([story]), forKey: "savedStories")
        let comment = try decode(#"{"id":43,"type":"comment","by":"reader","parent":42,"text":"A useful <i>comment</i> &amp; its context.","kids":[44],"time":1700000000}"#)

        let state = AppState(defaults: defaults)
        state.toggleSaved(comment)

        let restored = AppState(defaults: defaults)
        XCTAssertEqual(restored.savedItems, [comment, story])
        XCTAssertTrue(restored.isSaved(comment))
        XCTAssertEqual(restored.savedItems.first?.text, comment.text)
        XCTAssertEqual(restored.savedItems.first?.parent, story.id)
        XCTAssertEqual(restored.savedItems.first?.kids, [44])
        XCTAssertEqual(restored.savedItems.first?.discussionURL.absoluteString,
                       "https://news.ycombinator.com/item?id=43")

        restored.toggleSaved(comment)
        XCTAssertEqual(AppState(defaults: defaults).savedItems, [story])
    }

    @MainActor
    func testCorruptSavedDataDoesNotPreventStartup() throws {
        let suite = "HNReaderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.set(Data("invalid json".utf8), forKey: "savedStories")

        XCTAssertTrue(AppState(defaults: defaults).savedItems.isEmpty)
    }
}
