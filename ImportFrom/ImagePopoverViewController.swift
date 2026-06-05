import AppKit

final class ImagePopoverViewController: NSViewController {
    var image: NSImage? {
        didSet {
            (self.view as? ImageContainerView)?.image = image
        }
    }
    var onDragEnded: (() -> Void)?
    var onClose: (() -> Void)?

    override func loadView() {
        let container = ImageContainerView()
        container.onDragEnded = { [weak self] operation in
            if operation != [] {
                self?.onDragEnded?()
            }
        }
        self.view = container
    }
}

final class ImageContainerView: NSView {
    var image: NSImage? {
        didSet {
            imageView?.image = image
            imageView?.isHidden = (image == nil)
        }
    }
    var onDragEnded: ((NSDragOperation) -> Void)?
    private var imageView: DraggableImageView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        let iv = DraggableImageView()
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(iv)
        self.imageView = iv

        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iv.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            iv.heightAnchor.constraint(lessThanOrEqualToConstant: 260),
        ])
        let aspectConstraint = iv.widthAnchor.constraint(equalTo: iv.heightAnchor, multiplier: 1)
        aspectConstraint.priority = .defaultLow
        aspectConstraint.isActive = true
    }

    override func layout() {
        super.layout()
        if let image = image, let iv = imageView {
            let aspect = image.size.width / image.size.height
            let maxSize = CGSize(width: 260, height: 260)
            let targetSize: CGSize
            if maxSize.width / maxSize.height > aspect {
                targetSize = CGSize(width: maxSize.height * aspect, height: maxSize.height)
            } else {
                targetSize = CGSize(width: maxSize.width, height: maxSize.width / aspect)
            }
            iv.widthAnchor.constraint(equalToConstant: targetSize.width).isActive = true
            iv.heightAnchor.constraint(equalToConstant: targetSize.height).isActive = true
        }
    }
}

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
        onDragEnded?(operation)
    }
}
