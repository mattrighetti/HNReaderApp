import SwiftUI

struct ArticleFontSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Article font", selection: Binding(
                    get: { appState.articleFont },
                    set: { appState.articleFont = $0 }
                )) {
                    ForEach(ArticleFont.allCases) { font in
                        Text(font.name)
                            .font(.custom(font.fontName, size: 17))
                            .tag(font)
                    }
                }
                #if os(macOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif

                VStack(alignment: .leading, spacing: 24) {
                    ArticleTitle(
                        title: "The details that make reading a pleasure",
                        articleFont: appState.articleFont
                    )

                    ArticleBody(
                        text: """
                        <p>Good typography gives ideas room to breathe, with <b>bold thoughts</b> and <i>quiet emphasis</i>.</p>
                        """,
                        articleFont: appState.articleFont
                    )
                }
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Article Font")
    }
}

#if DEBUG
#Preview("Article font settings") {
    NavigationStack {
        ArticleFontSettingsView()
    }
    .environment(PreviewData.appState())
}
#endif
