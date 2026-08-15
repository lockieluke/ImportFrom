import AppKit
import SwiftUI

class PopoverController: NSObject {
    private let popover = NSPopover()
    
    var deviceName: String?

    override init() {
        super.init()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 300, height: 340)
        let viewController = ImagePopoverViewController()
        self.popover.contentViewController = viewController
    }

    func show(relativeTo button: NSStatusBarButton) {
        if let vc = self.popover.contentViewController as? ImagePopoverViewController {
            vc.image = nil
        }
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func showWithImage(_ image: NSImage, relativeTo button: NSStatusBarButton) {
        let viewController = ImagePopoverViewController()
        viewController.deviceName = self.deviceName
        viewController.image = image
        viewController.onDragEnded = { [weak self] in
            self?.dismiss()
        }
        viewController.onClose = { [weak self] in
            self?.dismiss()
        }
        self.popover.contentViewController = viewController
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func dismiss() {
        self.popover.performClose(nil)
    }

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
            print("Saved temp PNG to \(url.path())")
            tempFiles.insert(url)
            return url
        } catch {
            return nil
        }
    }
}
