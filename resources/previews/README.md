# SwiftUI previews

Open the relevant Swift file, enable **Editor → Canvas**, and choose a named preview.

| File | Canvas variants |
| --- | --- |
| [HomeView.swift](../../HNReader/View/HomeView.swift) | Full reader in light/dark, no selection, sidebar |
| [ItemList.swift](../../HNReader/View/ItemList.swift) | List in light/dark; loading, empty, search, offline, pagination; detail in light/dark with comment states |
| [SettingsView.swift](../../HNReader/View/SettingsView.swift) | System appearance, with light/dark Canvas variants |
| [InfoView.swift](../../HNReader/View/InfoView.swift) | About in light/dark |
| [ItemCell.swift](../../HNReader/View/ItemCell.swift) | Compact rows in light/dark, narrow, selected |
| [CommentView.swift](../../HNReader/View/CommentView.swift) | Expanded threads in light/dark, deep replies, collapsed threads |
| [CommentNavigator.swift](../../HNReader/View/CommentNavigator.swift) | Floating jump controls |
| [HTMLText.swift](../../HNReader/View/Components/HTMLText.swift) | Links, emphasis, code, compact comment text |
| [BgButton.swift](../../HNReader/View/Components/BgButton.swift) | Light/dark and disabled buttons |
| [ConditionalRedactedModifier.swift](../../HNReader/View/ConditionalRedactedModifier.swift) | Loaded text and placeholder |

Shared fixtures live in [PreviewData.swift](<../../HNReader/Preview Content/PreviewData.swift>).
Reader and detail previews disable automatic network loading. Preview preferences use isolated defaults rather than the app's saved settings.
