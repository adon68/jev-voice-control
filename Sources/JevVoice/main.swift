import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKeyRef: EventHotKeyRef?
    let controller = VoiceController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Jev Voice")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(controller)
        )

        controller.onListeningChanged = { [weak self] listening in
            if listening { self?.showPopover() }
        }
        controller.onDone = { [weak self] in
            self?.showPopover()
        }

        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    }

    @objc private func statusItemClicked() {
        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func registerHotKey() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassCarbon),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in delegate.controller.toggle() }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), handler, 1, &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(), nil
        )
        let hotKeyID = EventHotKeyID(signature: OSType(0x4A56_5631), id: 1) // "JVV1"
        RegisterEventHotKey(
            UInt32(kVK_Space), UInt32(optionKey), hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
