import AppKit
import Combine
import Dynamic

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
    fileprivate let actionObject: AnyObject

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SidecarService, rhs: SidecarService) -> Bool { lhs.id == rhs.id }
}

class SidecarHelper: NSResponder, NSServicesMenuRequestor, ObservableObject {

    static let shared = SidecarHelper()

    @Published var devices: [SidecarDevice] = []

    var onImageReceived: ((NSImage) -> Void)?

    private var sidecarCoreBundle: Bundle?
    private var sidecarUIBundle: Bundle?

    private override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func loadSidecarCore() -> Bool {
        if sidecarCoreBundle != nil { return true }
        let path = "/System/Library/PrivateFrameworks/SidecarCore.framework"
        guard let bundle = Bundle(path: path), bundle.load() else {
            print("[SidecarHelper] Failed to load SidecarCore.framework")
            return false
        }
        sidecarCoreBundle = bundle
        return true
    }

    private func loadSidecarUI() -> Bool {
        if sidecarUIBundle != nil { return true }
        let path = "/System/Library/PrivateFrameworks/SidecarUI.framework"
        guard let bundle = Bundle(path: path), bundle.load() else {
            print("[SidecarHelper] Failed to load SidecarUI.framework")
            return false
        }
        sidecarUIBundle = bundle
        return true
    }

    // MARK: - Device discovery

    func refreshDevices() {
        guard loadSidecarUI() else { return }
        guard let menuController = getMenuController() else { return }

        makeFirstResponder()

        let submenu = menuController.menu(withOptions: 0)
        submenu.update()

        guard let nsMenu = submenu.asObject as? NSMenu else {
            print("[SidecarHelper] Could not get NSMenu from submenu")
            return
        }

        logMenuStructure(nsMenu: nsMenu)

        var actions: [(deviceName: String, serviceName: String, actionObj: AnyObject)] = []
        var currentDeviceName: String? = nil

        for item in nsMenu.items {
            if item.isSeparatorItem { continue }
            
            if item.representedObject == nil {
                // No represented object: either a device header or a non-action item
                if !item.title.isEmpty && !isKnownServiceName(item.title) {
                    currentDeviceName = item.title
                }
            } else if let obj = item.representedObject,
                      let cls = NSClassFromString("SidecarServiceAction"),
                      (obj as AnyObject).isKind(of: cls) {
                // Service action item — assign to current device header
                let deviceName = currentDeviceName ?? extractDeviceName(from: obj) ?? "Device"
                actions.append((deviceName: deviceName, serviceName: localizedSidecarName(item.title), actionObj: obj as AnyObject))
            }
        }

        if actions.isEmpty {
            print("[SidecarHelper] No SidecarServiceAction objects found in menu")
            DispatchQueue.main.async { self.devices = [] }
            return
        }

        // Group by device name
        var grouped: [String: [SidecarService]] = [:]
        for (deviceName, serviceName, actionObj) in actions {
            let svc = SidecarService(id: "\(deviceName)_\(serviceName)", name: serviceName, actionObject: actionObj)
            grouped[deviceName, default: []].append(svc)
        }

        let discovered = grouped.map { (name, services) in
            SidecarDevice(id: name, name: name, services: services)
        }.sorted { $0.name < $1.name }

        print("[SidecarHelper] Discovered \(discovered.count) device(s)")
        for d in discovered {
            print("[SidecarHelper]   '\(d.name)': \(d.services.map { $0.name })")
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

        // Try: action.sidecarService.device.name
        if let name = safeString(dynAction.sidecarService.device.name) { return name }

        // Try: action.sidecarService.device.localizedDeviceType
        if let type = safeString(dynAction.sidecarService.device.localizedDeviceType) { return type }

        // Try: action.device.name (if SidecarServiceAction has a device property)
        if let name = safeString(dynAction.device.name) { return name }

        // Try: action.device.localizedDeviceType
        if let type = safeString(dynAction.device.localizedDeviceType) { return type }

        // Try: action.service.device.name
        if let name = safeString(dynAction.service.device.name) { return name }

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
        guard let firstDevice = devices.first,
              let firstService = firstDevice.services.first else {
            print("[SidecarHelper] No devices available")
            return
        }
        triggerService(firstService)
    }

    func triggerService(_ service: SidecarService) {
        makeFirstResponder()
        let pasteboard = NSPasteboard(name: .general)
        pasteboard.clearContents()
        let action = Dynamic(service.actionObject)
        action.invoke(withPasteboard: pasteboard)
    }

    func triggerTakePhoto() {
        guard let service = findFirstService(nameContains: "Photo") else {
            triggerImportFromIPhone()
            return
        }
        triggerService(service)
    }

    func triggerScanDocuments() {
        guard let service = findFirstService(nameContains: "Scan") else {
            triggerImportFromIPhone()
            return
        }
        triggerService(service)
    }

    func triggerPhotosBrowser() {
        guard loadSidecarUI() else { return }
        guard let menuController = getMenuController() else { return }
        makeFirstResponder()
        menuController.showPhotosBrowser(nil)
    }

    // MARK: - NSServicesMenuRequestor

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                               returnType: NSPasteboard.PasteboardType?) -> Any? {
        if let rt = returnType, NSImage.imageTypes.contains(rt.rawValue) {
            return self
        }
        return nil
    }

    @objc func readSelection(from pasteboard: NSPasteboard) -> Bool {
        guard pasteboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes),
              let image = NSImage(pasteboard: pasteboard) else {
            return false
        }
        onImageReceived?(image)
        return true
    }

    @objc func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        return false
    }

    // MARK: - Private helpers

    private func getMenuController() -> Dynamic? {
        guard let cls = NSClassFromString("SidecarMenuController") else {
            print("[SidecarHelper] SidecarMenuController class not found")
            return nil
        }
        let dynamicClass = Dynamic(cls)
        let controller = dynamicClass.sharedController
        return controller
    }

    private func findFirstService(nameContains: String) -> SidecarService? {
        for device in devices {
            if let service = device.services.first(where: { $0.name.localizedCaseInsensitiveContains(nameContains) }) {
                return service
            }
        }
        return nil
    }

    private func logMenuStructure(nsMenu: NSMenu, indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        print("[SidecarHelper] \(prefix)Menu \"\(nsMenu.title)\": \(nsMenu.items.count) items")
        for item in nsMenu.items {
            let represented = item.representedObject != nil ? String(describing: type(of: item.representedObject!)) : "nil"
            let hasAction = item.action != nil
            print("[SidecarHelper] \(prefix)  - \"\(item.title)\" action=\(hasAction) represented=\(represented) submenu=\(item.submenu != nil)")
            if let sub = item.submenu {
                logMenuStructure(nsMenu: sub, indent: indent + 1)
            }
        }
    }

    func makeFirstResponder() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow else { return }
            window.makeFirstResponder(self)
        }
    }
}
