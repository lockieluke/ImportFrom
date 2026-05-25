import AppKit
import SwiftUI

class OverlayPanel: NSPanel {
    private var hostingView: NSHostingView<OverlayView>!

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = true

        let view = OverlayView(image: nil, onClose: { [weak self] in
            self?.orderOut(nil)
        }, onDrop: { [weak self] in
            self?.orderOut(nil)
        })
        self.hostingView = NSHostingView(rootView: view)
        self.contentView = self.hostingView
    }

    func setImage(_ image: NSImage) {
        OverlayView.cleanupTempFiles()
        let view = OverlayView(image: image, onClose: { [weak self] in
            OverlayView.cleanupTempFiles()
            self?.orderOut(nil)
        }, onDrop: { [weak self] in
            self?.orderOut(nil)
        })
        self.hostingView.rootView = view
        self.hostingView.layout()
    }

    func positionBelow(_ button: NSStatusBarButton) {
        guard let screen = button.window?.screen else { return }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = button.window?.convertToScreen(buttonFrame) ?? buttonFrame
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 360
        var originX = screenFrame.midX - panelWidth / 2
        let originY = screenFrame.minY - panelHeight - 8
        if originX < screen.visibleFrame.minX {
            originX = screen.visibleFrame.minX + 8
        } else if originX + panelWidth > screen.visibleFrame.maxX {
            originX = screen.visibleFrame.maxX - panelWidth - 8
        }
        self.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
    }
}

struct OverlayView: View {
    var image: NSImage?
    let onClose: () -> Void
    let onDrop: () -> Void
    private static var tempFiles: Set<URL> = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)

            VStack(spacing: 12) {
                if let image = image {
                    DragImageRepresentable(image: image, onDrop: self.onDrop)
                        .frame(maxWidth: 260, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button(action: self.onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .frame(width: 320, height: 360)
    }

    static func cleanupTempFiles() {
        for url in self.tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        self.tempFiles.removeAll()
    }

    static func writeAndTrackTempPNG(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        do {
            try png.write(to: url)
            self.tempFiles.insert(url)
            self.scheduleCleanup(of: url)
            return url
        } catch {
            return nil
        }
    }

    private static func scheduleCleanup(of url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            try? FileManager.default.removeItem(at: url)
            self.tempFiles.remove(url)
        }
    }
}

struct DragImageRepresentable: NSViewRepresentable {
    let image: NSImage
    let onDrop: () -> Void

    func makeNSView(context: Context) -> DragImageView {
        let view = DragImageView()
        view.image = image
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DragImageView, context: Context) {
        nsView.image = image
        nsView.onDrop = onDrop
    }
}

final class DragImageView: NSView, NSDraggingSource {
    var image: NSImage? {
        didSet { self.needsDisplay = true }
    }
    var onDrop: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image = image else { return }
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

    override func mouseDragged(with event: NSEvent) {
        guard let image = image else { return }
        guard let url = OverlayView.writeAndTrackTempPNG(image) else { return }
        let nsurl = url as NSURL
        let draggingItem = NSDraggingItem(pasteboardWriter: nsurl)
        draggingItem.setDraggingFrame(self.bounds, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            onDrop?()
        }
    }
}
