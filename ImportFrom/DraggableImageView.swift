//
//  DraggableImageView.swift
//  ImportFrom
//
//  Created by Sherlock LUK on 31/07/2026.
//

import AppKit

final class DraggableImageView: NSView, NSDraggingSource {
    var image: NSImage? {
        didSet { self.needsDisplay = true }
    }
    var onDragEnded: ((NSDragOperation) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image = image else { return }
        let clipPath = NSBezierPath(roundedRect: self.bounds, xRadius: 8, yRadius: 8)
        clipPath.setClip()
        let rect = self.bounds
        let aspect = image.size.width / image.size.height
        var drawRect = rect
        if rect.width / rect.height > aspect {
            drawRect.size.width = rect.height * aspect
            drawRect.origin.x = (rect.width - drawRect.width) / 2
        } else {
            drawRect.size.height = rect.width / aspect
            drawRect.origin.y = (rect.height - drawRect.height) / 2
        }
        image.draw(in: drawRect, from: NSZeroRect, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard let image = image else { return }
        guard let url = PopoverController.writeAndTrackTempPNG(image) else { return }
        let nsurl = url as NSURL
        let draggingItem = NSDraggingItem(pasteboardWriter: nsurl)
        draggingItem.setDraggingFrame(self.bounds, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.onDragEnded?(operation)
    }
}
