import AppKit
import Combine
import Dynamic
import os.log

struct SidecarDevice: Identifiable, Hashable {
    let id: String
    let name: String
    var services: [SidecarService]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SidecarDevice, rhs: SidecarDevice) -> Bool { lhs.id == rhs.id }
}

struct SidecarService: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceName: String
    fileprivate let actionObject: AnyObject

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SidecarService, rhs: SidecarService) -> Bool { lhs.id == rhs.id }
}

class SidecarHelper: NSResponder, NSServicesMenuRequestor, ObservableObject {

    static let shared = SidecarHelper()

    @Published var devices: [SidecarDevice] = []

    var onImageReceived: ((NSImage, _ deviceName: String?) -> Void)?

    private var sidecarCoreBundle: Bundle?
    private var sidecarUIBundle: Bundle?
    
    private var deviceName: String?

    private override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func loadSidecarCore() -> Bool {
        if self.sidecarCoreBundle != nil { return true }
        let path = "/System/Library/PrivateFrameworks/SidecarCore.framework"
        guard let bundle = Bundle(path: path), bundle.load() else {
            Log.sidecar.error("Failed to load SidecarCore.framework")
            return false
        }
        self.sidecarCoreBundle = bundle
        return true
    }

    private func loadSidecarUI() -> Bool {
        if self.sidecarUIBundle != nil { return true }
        let path = "/System/Library/PrivateFrameworks/SidecarUI.framework"
        guard let bundle = Bundle(path: path), bundle.load() else {
            Log.sidecar.error("Failed to load SidecarUI.framework")
            return false
        }
        self.sidecarUIBundle = bundle
        return true
    }

    // MARK: - Device discovery

    func refreshDevices() {
        guard self.loadSidecarUI() else { return }
        guard let menuController = self.getMenuController() else { return }

        self.makeFirstResponder()

        let submenu = menuController.menu(withOptions: 0)
        submenu.update()

        guard let nsMenu = submenu.asObject as? NSMenu else {
            Log.sidecar.error("Could not get NSMenu from submenu")
            return
        }

        var actions: [(deviceName: String, serviceName: String, actionObj: AnyObject)] = []
        var currentDeviceName: String? = nil

        for item in nsMenu.items {
            if item.isSeparatorItem { continue }
            
            if item.representedObject == nil {
                // No represented object: either a device header or a non-action item
                if !item.title.isEmpty && !self.isKnownServiceName(item.title) {
                    currentDeviceName = item.title
                }
            } else if let obj = item.representedObject,
                      let cls = NSClassFromString("SidecarServiceAction"),
                      (obj as AnyObject).isKind(of: cls) {
                // Service action item — assign to current device header
                let deviceName = currentDeviceName ?? self.extractDeviceName(from: obj) ?? "Device"
                actions.append((deviceName: deviceName, serviceName: self.localizedSidecarName(item.title), actionObj: obj as AnyObject))
            }
        }

        if actions.isEmpty {
            Log.sidecar.info("No SidecarServiceAction objects found in menu")
            DispatchQueue.main.async { self.devices = [] }
            return
        }

        // Group by device name
        var grouped: [String: [SidecarService]] = [:]
        for (deviceName, serviceName, actionObj) in actions {
            let svc = SidecarService(id: "\(deviceName)_\(serviceName)", name: serviceName, deviceName: deviceName, actionObject: actionObj)
            grouped[deviceName, default: []].append(svc)
        }

        let discovered = grouped.map { (name, services) in
            SidecarDevice(id: name, name: name, services: services)
        }.sorted { $0.name < $1.name }

        Log.sidecar.info("Discovered \(discovered.count) device(s)")
        for d in discovered {
            Log.sidecar.info("  '\(d.name)': \(d.services.map { $0.name })")
        }

        DispatchQueue.main.async {
            self.devices = discovered
        }
    }

    private func extractDeviceName(from actionObj: Any) -> String? {
        let dynAction = Dynamic(actionObj)

        func safeString(_ dynamic: Dynamic) -> String? {
            if dynamic.isError { return nil }
            guard let str = dynamic.asString, !str.isEmpty else { return nil }
            guard !str.contains("InvocationError") else { return nil }
            return str
        }

        let candidates: [Dynamic] = [
            dynAction.sidecarService.device.name,
            dynAction.sidecarService.device.localizedDeviceType,
            dynAction.device.name,
            dynAction.device.localizedDeviceType,
            dynAction.service.device.name,
        ]

        for candidate in candidates {
            if let name = safeString(candidate) { return name }
        }

        return nil
    }

    private func localizedSidecarName(_ raw: String) -> String {
        let map: [String: String] = [
            "SidecarServiceNameTakePhoto": "Take Photo",
            "SidecarServiceNameScanDocument": "Scan Document",
            "SidecarServiceNameSketch": "Sketch",
            "SidecarServiceNameContinuityMarkUp": "Markup",
            "SidecarServiceNameClip": "Clip",
            "SidecarServiceNameLiveDrawing": "Live Drawing",
        ]
        return map[raw] ?? raw
    }

    private func isKnownServiceName(_ title: String) -> Bool {
        let known = [
            "SidecarServiceNameTakePhoto",
            "SidecarServiceNameScanDocument",
            "SidecarServiceNameSketch",
            "SidecarServiceNameContinuityMarkUp",
            "SidecarServiceNameClip",
            "SidecarServiceNameLiveDrawing",
            "Take Photo",
            "Scan Document",
            "Sketch",
            "Markup",
            "Clip",
            "Live Drawing",
        ]
        return known.contains(title)
    }

    // MARK: - High-level triggers

    func triggerImportFromIPhone() {
        guard let firstDevice = self.devices.first,
              let firstService = firstDevice.services.first else {
            Log.sidecar.info("No devices available")
            return
        }
        self.triggerService(firstService)
    }

    func triggerService(_ service: SidecarService) {
        self.deviceName = service.deviceName
        self.makeFirstResponder()
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        
        self.startPasteboardFallback(initialChangeCount: initialChangeCount)
        
        let action = Dynamic(service.actionObject)
        action.invoke(withPasteboard: pasteboard)
    }

    func triggerTakePhoto() {
        guard let service = self.findFirstService(nameContains: "Photo") else {
            self.triggerImportFromIPhone()
            return
        }
        self.triggerService(service)
    }

    func triggerScanDocuments() {
        guard let service = self.findFirstService(nameContains: "Scan") else {
            self.triggerImportFromIPhone()
            return
        }
        self.triggerService(service)
    }

    func triggerPhotosBrowser() {
        guard self.loadSidecarUI() else { return }
        guard let menuController = self.getMenuController() else { return }
        self.makeFirstResponder()
        menuController.showPhotosBrowser(nil)
    }

    // MARK: - NSServicesMenuRequestor

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                               returnType: NSPasteboard.PasteboardType?) -> Any? {
        Log.sidecar.info("validRequestor sendType=\(sendType?.rawValue ?? "nil") returnType=\(returnType?.rawValue ?? "nil")")
        if let rt = returnType, NSImage.imageTypes.contains(rt.rawValue) {
            return self
        }
        return nil
    }

    @objc func readSelection(from pasteboard: NSPasteboard) -> Bool {
        Log.sidecar.info("readSelection called")
        guard pasteboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes),
              let image = NSImage(pasteboard: pasteboard) else {
            Log.sidecar.error("readSelection: could not read image from pasteboard")
            return false
        }
        Log.sidecar.info("readSelection: image received \(image.size.width)x\(image.size.height)")
        self.stopPasteboardFallback()
        self.onImageReceived?(image, self.deviceName)
        return true
    }

    @objc func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        Log.sidecar.info("writeSelection called types=\(types)")
        return false
    }

    // MARK: - Private helpers

    private func getMenuController() -> Dynamic? {
        guard let cls = NSClassFromString("SidecarMenuController") else {
            Log.sidecar.error("SidecarMenuController class not found")
            return nil
        }
        let dynamicClass = Dynamic(cls)
        let controller = dynamicClass.sharedController
        return controller
    }

    private func findFirstService(nameContains: String) -> SidecarService? {
        for device in self.devices {
            if let service = device.services.first(where: { $0.name.localizedCaseInsensitiveContains(nameContains) }) {
                return service
            }
        }
        return nil
    }

    override var acceptsFirstResponder: Bool { true }

    func makeFirstResponder() {
        let work = {
            guard let window = NSApp.keyWindow else { return }
            window.makeFirstResponder(self)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    // MARK: - Pasteboard fallback

    private var fallbackTimer: Timer?

    private func startPasteboardFallback(initialChangeCount: Int) {
        self.stopPasteboardFallback()
        Log.sidecar.info("Starting pasteboard fallback timer (initial changeCount=\(initialChangeCount))")

        var lastSeenChangeCount = initialChangeCount
        var ticksSinceChange = 0
        let maxTicks = 100

        self.fallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let pb = NSPasteboard.general
            let currentCount = pb.changeCount

            if currentCount > lastSeenChangeCount {
                lastSeenChangeCount = currentCount
                ticksSinceChange = 0
                if pb.canReadItem(withDataConformingToTypes: NSImage.imageTypes),
                   let image = NSImage(pasteboard: pb) {
                    Log.sidecar.info("Fallback found image: \(image.size.width)x\(image.size.height)")
                    self.stopPasteboardFallback()
                    self.onImageReceived?(image, self.deviceName)
                    return
                }
            }

            ticksSinceChange += 1

            if ticksSinceChange >= 5 {
                Log.sidecar.info("Pasteboard fallback stopped (cancelled or empty)")
                self.stopPasteboardFallback()
                return
            }

            if ticksSinceChange >= maxTicks {
                Log.sidecar.info("Pasteboard fallback timed out")
                self.stopPasteboardFallback()
            }
        }
    }

    private func stopPasteboardFallback() {
        self.fallbackTimer?.invalidate()
        self.fallbackTimer = nil
    }
}
