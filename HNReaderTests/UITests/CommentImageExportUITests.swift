import XCTest

@MainActor
final class CommentImageExportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(long: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--comment-image-fixture"] + (long ? ["--comment-image-long"] : [])
        app.launch()
        XCTAssertTrue(app.staticTexts["fixture_author"].waitForExistence(timeout: 10))
        return app
    }

    private func openImage(_ app: XCUIApplication, from element: XCUIElement, id: Int = 8863) {
        element.press(forDuration: 1)
        let action = app.buttons["comment.image.export.\(id)"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        XCTAssertTrue(app.navigationBars["Comment Image"].waitForExistence(timeout: 5))
    }

    func testHeaderMenuPreviewAndAppearance() {
        let app = launch()
        openImage(app, from: app.staticTexts["fixture_author"])
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
        app.buttons["comment.image.background"].tap()
        app.buttons["Midnight"].tap()
        // The iPad sheet is shorter than the full preview and appearance form.
        // Reveal controls that may have been recycled while the preview updated.
        app.collectionViews.firstMatch.swipeUp()
        let watermark = app.switches["HNReader watermark"]
        XCTAssertTrue(watermark.waitForExistence(timeout: 5))
        // Some OS/device combinations expose the whole row as a Switch;
        // others expose only the native control. Tap its trailing control area.
        watermark.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -40, dy: 0)).tap()
        XCTAssertEqual(watermark.value as? String, "0")
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Comment image preview"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["fixture_author"].waitForExistence(timeout: 5))
    }

    func testBodyLongPressAndSystemSharing() {
        let app = launch()
        openImage(app, from: app.textViews.firstMatch)
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
        app.buttons["Share Image"].tap()
        // System share actions are collection cells, rather than buttons.
        XCTAssertTrue(app.cells["Copy"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.otherElements["LP.CaptionBar.TopCaption"].label, "hn-comment-8863")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "PNG system share sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["header.closeButton"].tap()
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 5))
        app.buttons["Share Image"].tap()
        XCTAssertTrue(app.cells["Copy"].waitForExistence(timeout: 15))
        app.buttons["header.closeButton"].tap()
    }

    func testNestedReplyAndCollapsedComment() {
        let app = launch()
        openImage(app, from: app.staticTexts["fixture_reply"], id: 8864)
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        app.buttons["Collapse comment and replies"].firstMatch.tap()
        openImage(app, from: app.staticTexts["fixture_author"])
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
    }

    func testLongCommentOffersLinkFallback() {
        let app = launch(long: true)
        openImage(app, from: app.staticTexts["fixture_author"])
        XCTAssertTrue(app.staticTexts["This comment is too long for one image."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Share Image"].isEnabled)
        XCTAssertTrue(app.buttons["Share Comment Link"].exists)
    }

    func testContentOptionsApplyToNestedCommentPreview() {
        let app = launch()
        openImage(app, from: app.staticTexts["fixture_reply"], id: 8864)
        XCTAssertTrue(app.images["comment.image.preview"].waitForExistence(timeout: 10))
        app.collectionViews.firstMatch.swipeUp()
        let username = app.switches["Include username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -40, dy: 0)).tap()
        let title = app.switches["Include article title"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -40, dy: 0)).tap()
        XCTAssertEqual(username.value as? String, "0")
        XCTAssertEqual(title.value as? String, "1")
        app.collectionViews.firstMatch.swipeDown()
        let preview = app.images["comment.image.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let label = NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)",
                                "Building tools people want", "fixture_reply")
        expectation(for: label, evaluatedWith: preview)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["Share Image"].isEnabled)
    }
}
