import SwiftUI
import UIKit

/// Each activity session owns its file until the system sheet finishes using it.
final class CommentImageShareFile: Identifiable {
    let id = UUID()
    let url: URL
    private let directory: URL

    init(png: Data, commentID: Int) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommentImage-\(id.uuidString)", isDirectory: true)
        url = directory.appendingPathComponent("hn-comment-\(commentID).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

struct CommentImageShareSheet: UIViewControllerRepresentable {
    let file: CommentImageShareFile

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        // Retain the file through the activity's completion, including cancellation.
        controller.completionWithItemsHandler = { [file] _, _, _, _ in _ = file }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
