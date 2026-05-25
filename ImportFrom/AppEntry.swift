import AppKit
import SwiftUI
import Combine
@_exported import SFSafeSymbols

@main
struct ImportFrom {
    @MainActor
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.setupStatusItem()
        self.observeDevices()
        SidecarHelper.shared.onImageReceived = { [weak self] image in
            self?.showOverlay(image: image)
        }
        self.refreshDevices()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbol: .iphone, accessibilityDescription: "ImportFrom")
        }
        self.rebuildMenu()
    }

    private func observeDevices() {
        SidecarHelper.shared.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &self.cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let devices = SidecarHelper.shared.devices
        
        let appTitleItme = NSMenuItem(title: "ImportFrom", action: nil, keyEquivalent: "")
        appTitleItme.isEnabled = false
        menu.addItem(appTitleItme)
        menu.addItem(.separator())

        if devices.isEmpty {
            let emptyItem = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for device in devices {
                let header = NSMenuItem(title: device.name, action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
                for service in device.services {
                    let item = NSMenuItem(
                        title: "    \(service.name)",
                        action: #selector(self.importFromService(_:)),
                        keyEquivalent: ""
                    )
                    item.representedObject = service
                    menu.addItem(item)
                }
                menu.addItem(.separator())
            }
        }

        menu.addItem(NSMenuItem(title: "Refresh Devices", action: #selector(self.refreshDevices), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(self.quit), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    @objc private func importFromService(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? SidecarService else { return }
        self.preparePanelForImport()
        SidecarHelper.shared.triggerService(service)
    }

    @objc private func refreshDevices() {
        DispatchQueue.global(qos: .userInitiated).async {
            SidecarHelper.shared.refreshDevices()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Overlay Panel

    private func preparePanelForImport() {
        if self.panel == nil {
            self.panel = OverlayPanel()
        }
        self.panel?.alphaValue = 0
        self.panel?.makeKeyAndOrderFront(nil)
    }

    private func showOverlay(image: NSImage) {
        if self.panel == nil {
            self.panel = OverlayPanel()
        }
        self.panel?.setImage(image)
        if let button = self.statusItem.button {
            self.panel?.positionBelow(button)
        }
        self.panel?.alphaValue = 1
        self.panel?.makeKeyAndOrderFront(nil)
    }
}
