# Preview gallery

These images use local sample data. You can inspect them without launching HNReader.

| Screen | Previews |
| --- | --- |
| Full reader | [Light](reader-light.png) · [Dark](reader-dark.png) |
| Sidebar | [Saved library](sidebar.png) |
| Story list | [Light](story-list-light.png) · [Dark](story-list-dark.png) |
| Initial loading | [Loading stories](story-list-loading.png) |
| Empty library | [No saved stories](story-list-empty-saved.png) |
| Search | [No results](story-list-no-results.png) |
| Feed error | [Offline](story-list-offline.png) |
| Pagination | [Loading next page](story-list-loading-page.png) · [Retry](story-list-page-error.png) |
| Story detail | [Light](story-detail-light.png) · [Dark](story-detail-dark.png) |
| Compact story rows | [Light](compact-stories-light.png) · [Dark](compact-stories-dark.png) · [Selected](compact-stories-selected.png) |
| Comment threads | [Light](comment-threads-light.png) · [Dark](comment-threads-dark.png) · [Collapsed](comment-threads-collapsed.png) |
| Comment navigation | [Light](comment-navigation-light.png) · [Dark](comment-navigation-dark.png) |

## Xcode Canvas

Open the relevant Swift file, enable **Editor → Canvas**, and choose a named preview.

| File | Canvas variants |
| --- | --- |
| [HomeView.swift](../../HNReader/View/HomeView.swift) | Full reader in light/dark, no selection, sidebar |
| [ItemList.swift](../../HNReader/View/ItemList.swift) | List in light/dark; loading, empty, search, offline, pagination; detail in light/dark with comment states |
| [ItemCell.swift](../../HNReader/View/ItemCell.swift) | Compact rows in light/dark, narrow, selected |
| [CommentView.swift](../../HNReader/View/CommentView.swift) | Expanded threads in light/dark, collapsed threads |
| [CommentNavigator.swift](../../HNReader/View/CommentNavigator.swift) | Floating jump controls |
| [HTMLText.swift](../../HNReader/View/Components/HTMLText.swift) | Links, emphasis, code, compact comment text |
| [BgButton.swift](../../HNReader/View/Components/BgButton.swift) | Light/dark and disabled buttons |
| [ConditionalRedactedModifier.swift](../../HNReader/View/ConditionalRedactedModifier.swift) | Loaded text and placeholder |

Shared fixtures live in [PreviewData.swift](<../../HNReader/Preview Content/PreviewData.swift>).
Reader and detail previews disable automatic network loading. Preview preferences use isolated defaults rather than the app's saved settings.
