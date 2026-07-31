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
