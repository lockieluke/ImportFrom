import AppKit
import SwiftUI

class PopoverController: NSObject {
    private let popover = NSPopover()

    override init() {
        super.init()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 300, height: 340)
        let viewController = ImagePopoverViewController()
        self.popover.contentViewController = viewController
    }

    func show(relativeTo button: NSStatusBarButton) {
        PopoverController.cleanupTempFiles()
        if let vc = self.popover.contentViewController as? ImagePopoverViewController {
            vc.image = nil
        }
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func showWithImage(_ image: NSImage, relativeTo button: NSStatusBarButton) {
        PopoverController.cleanupTempFiles()
        let viewController = ImagePopoverViewController()
        viewController.image = image
        viewController.onDragEnded = { [weak self] in
            PopoverController.cleanupTempFiles()
            self?.dismiss()
        }
        viewController.onClose = { [weak self] in
            PopoverController.cleanupTempFiles()
            self?.dismiss()
        }
        self.popover.contentViewController = viewController
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func dismiss() {
        PopoverController.cleanupTempFiles()
        self.popover.performClose(nil)
    }

    // MARK: - Temp file management

    private static var tempFiles: Set<URL> = []

    static func cleanupTempFiles() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }

    static func writeAndTrackTempPNG(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        let quality = ImageQuality.current
        let properties: [NSBitmapImageRep.PropertyKey: Any] = quality == .original
            ? [:]
            : [.compressionFactor: quality.compression]
        guard let data = bitmap.representation(using: quality.bitmapType, properties: properties) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".\(quality.fileExtension)")
        do {
            try data.write(to: url)
            tempFiles.insert(url)
            self.scheduleCleanup(of: url)
            return url
        } catch {
            return nil
        }
    }

    private static func scheduleCleanup(of url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            try? FileManager.default.removeItem(at: url)
            tempFiles.remove(url)
        }
    }
}
