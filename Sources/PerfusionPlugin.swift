import AppKit
import SwiftUI
import IsiXPluginKit

@MainActor
public final class UMMPerfusionIsiXPlugin: IsiXPlugin {
    private var window: NSWindow?
    private var controller: PerfusionController?

    public init() {}

    public func activate(with context: IsiXPluginContext) throws {
        try context.register(
            IsiXCommand(
                id: "umm-perfusion-native",
                title: L("menu"),
                placement: .imageFilters,
                requirement: .viewer
            )
        ) { [weak self] invocation in
            guard let viewer = invocation.viewer else { return }
            self?.showWindow(context: context, viewer: viewer)
        }
    }

    public func deactivate() {
        controller?.cancel()
        window?.close()
        window = nil
        controller = nil
    }

    private func showWindow(context: IsiXPluginContext, viewer: IsiXViewer) {
        if let window, let controller {
            controller.connect(to: viewer)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = PerfusionController(context: context, viewer: viewer)
        let hostingController = NSHostingController(rootView: PerfusionView(controller: controller))
        let window = NSWindow(contentViewController: hostingController)
        window.title = L("title")
        window.setContentSize(NSSize(width: 760, height: 780))
        window.minSize = NSSize(width: 650, height: 610)
        window.isReleasedWhenClosed = false
        window.center()
        self.controller = controller
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
