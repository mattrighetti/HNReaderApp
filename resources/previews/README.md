# SwiftUI previews

Open the relevant Swift file, enable **Editor → Canvas**, and choose a named preview.

## Select the matching scheme

These are two native app targets. Canvas uses the active scheme and run destination:

| Source location | Scheme | Destination |
| --- | --- | --- |
| `HNReader/Platforms/macOS/` | `HNReader` | My Mac |
| `HNReader/Platforms/iOS/` | `HNReader iOS` | An iPhone or iPad simulator |
| `HNReader/Shared/` | Either scheme | A destination for the selected platform |

“Active scheme does not build this file” means the open file is not a source of the selected target. For example, `IOSSettingsView.swift` requires `HNReader iOS`; `Platforms/macOS/SettingsView.swift` requires `HNReader`. Switch the scheme and destination, then resume Canvas. Platform-specific files deliberately belong only to their own target.

If a shared file shows no previews, check whether its declarations are guarded by `#if os(macOS)` or `#if os(iOS)`. Selecting a different Canvas device does not change the active scheme.

## Preview index

| File | Scheme | Canvas variants |
| --- | --- | --- |
| [HomeView.swift](../../HNReader/Shared/View/HomeView.swift) | Both | Mac reader in light/dark, no selection, sidebar; iOS reader |
| [IOSHomeView.swift](../../HNReader/Platforms/iOS/IOSHomeView.swift) | iOS | Saved stories and comments in light/dark; live article |
| [StoryDetail.swift](../../HNReader/Shared/View/StoryDetail.swift) | Both | Discussion with local fixtures |
| [UserCommentsView.swift](../../HNReader/Shared/View/UserCommentsView.swift) | Both | User comments with local fixtures |
| [IOSSettingsView.swift](../../HNReader/Platforms/iOS/IOSSettingsView.swift) | iOS | App icon picker |
| [SettingsView.swift](../../HNReader/Platforms/macOS/SettingsView.swift) | Mac | System appearance, light/dark |
| [ItemList.swift](../../HNReader/Shared/View/ItemList.swift) | Both | Mac lists and discussion states; iOS story list |
| [ItemCell.swift](../../HNReader/Shared/View/ItemCell.swift) | Mac | Compact rows in light/dark, narrow, selected, saved comments |
| [UserDetailView.swift](../../HNReader/Shared/View/UserDetailView.swift) | Both | User profile fixture; live profile |
| [InfoView.swift](../../HNReader/Shared/View/InfoView.swift) | Both | About in light/dark |
| [CommentView.swift](../../HNReader/Shared/View/CommentView.swift) | Both | Expanded threads, deep replies, collapsed threads, saved comment |
| [CommentTextView.swift](../../HNReader/Shared/View/Components/CommentTextView.swift) | Both | Quotes, HN formatting, code, links, dark |
| [CommentNavigator.swift](../../HNReader/Shared/View/CommentNavigator.swift) | Both | Floating jump controls |
| [HTMLText.swift](../../HNReader/Shared/View/Components/HTMLText.swift) | Both | Links, emphasis, code, compact comment text |
| [BgButton.swift](../../HNReader/Shared/View/Components/BgButton.swift) | Both | Light/dark and disabled buttons |
| [ConditionalRedactedModifier.swift](../../HNReader/Shared/View/ConditionalRedactedModifier.swift) | Both | Loaded text and placeholder |

Shared fixtures live in [PreviewData.swift](<../../HNReader/Shared/Preview Content/PreviewData.swift>).
Fixture previews disable automatic network loading and use isolated defaults rather than the app’s saved settings. Previews explicitly named “Live” make real network requests.
