import Foundation
import os.log

private let subsystem = Bundle.main.bundleIdentifier ?? "ImportFrom"

enum Log {
    static let sidecar = Logger(subsystem: subsystem, category: "SidecarHelper")
}
