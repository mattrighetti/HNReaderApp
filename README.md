<p align="center">
    <img src="https://user-images.githubusercontent.com/16304728/121924791-85b69780-cd3c-11eb-90d8-9861d0bf424e.png" height="250">
</p>

# HNReaderApp
This is the public repository for the HNReader macOS application. 

You can report any issue and suggest/request new features in the [issue](https://github.com/mattrighetti/HNReaderApp/issues) section, you can also use the [discussions](https://github.com/mattrighetti/HNReaderApp/discussions) section to chat with others and me about the application.

The application is still in beta for the moment and needs optimizations. When the time come I will release it to AppStore and on `brew`.

<p align="center">
<a href="https://apps.apple.com/it/app/hnews-reader/id1572480416?l=en&mt=12">
<img src="resources/appstore.png" height="50px" />
</a>
</p>

## Modern macOS reader

The app targets macOS 14 or later and uses a native three-column SwiftUI interface:

- Top, Latest, Best, Ask HN, Show HN, and Jobs feeds.
- In-app discussions with curved thread connectors, collapsible comments, author avatars,
  original-poster badges, selectable text, sharing, and replies loaded on demand.
- Saved stories and read status persisted locally across launches.
- Search by title, author, or domain within the loaded feed or saved stories.
- Unread filtering, automatic pagination, and loading/error/retry states.
- Native sharing, article links, and System / Light / Dark appearance.

Open `HNReader.xcodeproj` in Xcode and run the `HNReader` scheme.
Use **⌘R** to refresh a feed and **⌘D** to save or unsave the selected story.
Articles open in your default browser. Saved story metadata is available offline;
discussions require a connection. Bookmarks and read status are stored on this Mac.

Feed data comes from the official Hacker News Firebase REST API. The app loads
30 stories per page, with at most eight item requests in flight. A page appears
only when every request has finished, preserving ranking without individual row
insertions. Scrolling to the bottom automatically requests the next 30 stories.
Failed pages leave the existing list intact and can be retried.

Visited sections retain their loaded pages for one minute. A shared `NSCache` in
`HNClient/ItemCache.swift` reuses story and comment metadata for two minutes and
allows eviction under memory pressure. Networking lives in `HNClient/NewsService.swift`.
**⌘R** requests fresh IDs and first-page metadata.

Open `View/ItemCell.swift` in Xcode’s Canvas for light, dark, and narrow compact-row
previews. `View/CommentView.swift` also includes expanded and collapsed comment-thread
previews. They use local sample data and do not need the app or network to run.

To run the deterministic tests without live API requests:

```sh
xcodebuild -project HNReader.xcodeproj -scheme HNReader \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -skip-testing:HNReaderTests/HackerNewsClientTests test
```

## License
[MIT](LICENSE) or [APACHE 2.0](LICENSE)
