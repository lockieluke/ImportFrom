# Agent Instructions for ImportFrom

## Project Overview

Small SwiftUI macOS app that triggers "Import from iPhone" (Continuity Camera) programmatically using private `SidecarUI.framework` / `SidecarCore.framework` APIs via the [`Dynamic`](https://github.com/mhdhejazi/Dynamic) library.

## Build & Run

```bash
# Build
xcodebuild -project ImportFrom.xcodeproj -scheme ImportFrom build

# Run (Debug build location)
~/Library/Developer/Xcode/DerivedData/ImportFrom-*/Build/Products/Debug/ImportFrom.app/Contents/MacOS/ImportFrom
```

## Architecture

| File | Purpose |
|------|---------|
| `ImportFrom/ImportFromApp.swift` | SwiftUI `@main` app entrypoint |
| `ImportFrom/ContentView.swift` | SwiftUI UI — device picker, action menus, image display |
| `ImportFrom/SidecarHelper.swift` | Private API bridge — loads `SidecarUI.framework` + `SidecarCore.framework` at runtime, discovers devices via `SidecarMenuController`, triggers `SidecarServiceAction.invoke(withPasteboard:)`, and receives images via `NSServicesMenuRequestor` |

## Key Implementation Details

### Private API Access
- Uses `Dynamic` library to call Objective-C private API in Swift: `Dynamic(classRef).someMethod(args)`
- Wraps results in `Dynamic` objects — always check `.isError` before `.asString`/etc. Error descriptions leak into UI if unguarded

### Runtime Framework Loading
```swift
Bundle(path: "/System/Library/PrivateFrameworks/SidecarUI.framework")?.load()
Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework")?.load()
```
- Frameworks are loaded lazily on first use
- Binaries are in the dyld shared cache on Apple Silicon (broken symlinks in framework bundles)

### Responder Chain Requirement
- `SidecarHelper` is an `NSResponder` subclass conforming to `NSServicesMenuRequestor`
- Must be the window's `firstResponder` before triggering any action, otherwise Continuity Camera won't deliver results
- `readSelection(from:)` receives the captured `NSImage` from the pasteboard

### Device Discovery
- `SidecarMenuController.sharedController.menu(withOptions:)` creates a `SidecarSubmenu`
- Call `.update()` on it to populate with available devices and services
- Devices appear as parent `NSMenuItem`s with submenus containing `SidecarServiceAction` items
- `SidecarServiceAction.representedObject` on menu items holds the invocable action object

### Triggering Actions
- Store the actual `SidecarServiceAction` objects (as `AnyObject`) — do NOT re-search menus by title
- Call `Dynamic(actionObject).invoke(withPasteboard:)` directly with a fresh `NSPasteboard`
- Each device has its own `SidecarServiceAction` instances — triggering by title match hits the first device only

## Dependencies

- [`Dynamic`](https://github.com/mhdhejazi/Dynamic) v1.2.0 — SwiftPM package for calling private/hidden Objective-C APIs

## Testing Notes

- No test target exists in the project
- Requires a real iPhone/iPad on the same Apple ID nearby for Continuity Camera to populate the device list
- Console logs from `SidecarHelper` print full menu structure on refresh — use for debugging device discovery issues
