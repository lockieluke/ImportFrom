import AppKit
import SwiftUI

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
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] applicationDidFinishLaunching")
        self.createWindow()
        self.setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)

        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.window.title = "ImportFrom"
        self.window.isRestorable = false
        self.window.contentViewController = hostingController
        self.window.center()
        self.window.makeKeyAndOrderFront(nil)
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        func submenu(_ title: String? = nil, _ build: (NSMenu) -> Void) {
            let menu = title != nil ? NSMenu(title: title!) : NSMenu()
            build(menu)
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        func item(_ title: String, _ action: Selector?, key: String = "", mask: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
            mi.keyEquivalentModifierMask = mask
            return mi
        }

        // App menu
        submenu { menu in
            menu.addItem(item(String(format: sys("About %@"), appName), #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(item(String(format: sys("Hide %@"), appName), #selector(NSApplication.hide(_:)), key: "h"))
            menu.addItem(item(sys("Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), key: "h", mask: [.command, .option]))
            menu.addItem(item(sys("Show All"), #selector(NSApplication.unhideAllApplications(_:))))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(item(String(format: sys("Quit %@"), appName), #selector(NSApplication.terminate(_:)), key: "q"))
        }

        // File menu
        submenu(sys("File")) { menu in
            menu.addItem(item(sys("Close"), #selector(NSWindow.performClose(_:)), key: "w"))
        }

        // Edit menu
        submenu(sys("Edit")) { menu in
            menu.addItem(item(sys("Undo"), Selector(("undo:")), key: "z"))
            menu.addItem(item(sys("Redo"), Selector(("redo:")), key: "Z"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(item(sys("Cut"), #selector(NSText.cut(_:)), key: "x"))
            menu.addItem(item(sys("Copy"), #selector(NSText.copy(_:)), key: "c"))
            menu.addItem(item(sys("Paste"), #selector(NSText.paste(_:)), key: "v"))
            menu.addItem(item(sys("Delete"), #selector(NSText.delete(_:))))
            menu.addItem(item(sys("Select All"), #selector(NSText.selectAll(_:)), key: "a"))
        }

        // Window menu
        submenu(sys("Window")) { menu in
            menu.addItem(item(sys("Minimize"), #selector(NSWindow.performMiniaturize(_:)), key: "m"))
            menu.addItem(item(sys("Zoom"), #selector(NSWindow.performZoom(_:))))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(item(sys("Bring All to Front"), #selector(NSApplication.arrangeInFront(_:))))
        }

        // Help menu
        submenu(sys("Help")) { menu in
            menu.addItem(item(String(format: sys("%@ Help"), appName), nil as Selector?))
        }

        NSApp.mainMenu = mainMenu
    }
}
