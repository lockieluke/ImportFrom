import AppKit

/// Attempts to read a system-localised string from AppKit's bundle.
/// Falls back to the app's own `Localizable.strings` if AppKit does not have the key.
func sys(_ key: String) -> String {
    let appKitBundle = Bundle(for: NSApplication.self)
    let tables = ["MenuCommands", "AppKit", nil]
    for table in tables {
        let value = appKitBundle.localizedString(forKey: key, value: nil, table: table)
        if value != key {
            return value
        }
    }
    return NSLocalizedString(key, comment: "")
}

func makeDeviceNameSafe(_ deviceName: String) -> String {
    let table = [
        " ": "_",
        "'": "",
    ]
    
    var safeName = deviceName
    for (key, value) in table {
        safeName = safeName.replacingOccurrences(of: key, with: value)
    }
    
    return safeName
}
