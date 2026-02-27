import AppKit

enum WindowRouter {
    static func closeAppUIOnly() {
        NSApp.hide(nil)
    }
}
