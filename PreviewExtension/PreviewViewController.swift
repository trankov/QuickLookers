import Cocoa
import Quartz
import os

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        Self.log.info("preparePreviewOfFile pid=\(getpid()) url=\(url.lastPathComponent, privacy: .public)")
    }
}
