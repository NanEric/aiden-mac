import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let item: NSStatusItem
    private let popover: NSPopover
    private let rootViewModel = RootTrayViewModel()

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        configure()
    }

    private func configure() {
        if let button = item.button {
            button.title = "Aiden"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let rootView = RootTrayView(viewModel: rootViewModel)
        popover.contentSize = NSSize(width: 430, height: 440)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    func startBootstrap() {
        rootViewModel.bootstrap()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let anchor = NSRect(
                x: button.bounds.midX - 0.5,
                y: button.bounds.minY,
                width: 1,
                height: button.bounds.height
            )
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
        }
    }
}
