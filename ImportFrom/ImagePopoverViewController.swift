import AppKit
import SwiftUI

final class ImagePopoverViewController: NSViewController {
    var image: NSImage? {
        didSet {
            (self.view as? ImageContainerView)?.image = image
        }
    }
    var onDragEnded: (() -> Void)?
    var onClose: (() -> Void)?
    var deviceName: String?

    override func loadView() {
        let container = ImageContainerView()
        container.deviceName = self.deviceName
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
            self.needsLayout = true
        }
    }
    var onDragEnded: ((NSDragOperation) -> Void)?
    var deviceName: String?
    private var imageView: DraggableImageView?
    private var actionsView: ImageActionsView?
    private var ivWidthConstraint: NSLayoutConstraint?
    private var ivHeightConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: NSSize { NSSize(width: 300, height: 340) }

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
        iv.onDragEnded = { [weak self] operation in
            self?.onDragEnded?(operation)
        }
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 20),
            iv.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            iv.heightAnchor.constraint(lessThanOrEqualToConstant: 300),
        ])
        self.imageView = iv
        
        let formatter = DateFormatter()
        let date = Date()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        
        let displayedTimestamp = formatter.string(from: date)
        
        let actionsView = ImageActionsView(onCopy: {
            NSPasteboard.general.clearContents()
            if let image = self.image {
                NSPasteboard.general.writeObjects([image])
            }
        }, onSave: {
            if let image = self.image {
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let fileURL = downloadsURL.appendingPathComponent("ImportedFrom_\(self.deviceName ?? "Unknown")_\(timestamp).png")
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    return
                }
                do {
                    try pngData.write(to: fileURL)
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                } catch {
                    print("Failed to save image: \(error)")
                }
            }
        })
        let hostedActionsView = NSHostingView(rootView: actionsView)
        hostedActionsView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(hostedActionsView)
        self.actionsView = actionsView

        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iv.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            iv.heightAnchor.constraint(lessThanOrEqualToConstant: 260),

            hostedActionsView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            hostedActionsView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
        ])
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
            if let w = self.ivWidthConstraint, let h = self.ivHeightConstraint {
                w.constant = targetSize.width
                h.constant = targetSize.height
            } else {
                let w = iv.widthAnchor.constraint(equalToConstant: targetSize.width)
                let h = iv.heightAnchor.constraint(equalToConstant: targetSize.height)
                NSLayoutConstraint.activate([w, h])
                self.ivWidthConstraint = w
                self.ivHeightConstraint = h
            }
        }
    }
}
