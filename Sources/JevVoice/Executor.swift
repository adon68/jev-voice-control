import AppKit
import CoreGraphics
import JevVoiceCore

enum ExecutorError: Error, LocalizedError {
    case appNotFound(String)
    case missingSlot(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let name): return "Could not find app: \(name)"
        case .missingSlot(let what): return "Missing \(what)"
        }
    }
}

enum Executor {
    @MainActor
    static func execute(_ decision: Decision) async throws -> String {
        switch decision.action {
        case .openApp:
            guard let name = decision.targetApp else { throw ExecutorError.missingSlot("target app") }
            return try await openApp(named: name)
        case .closeApp:
            guard let name = decision.targetApp else { throw ExecutorError.missingSlot("target app") }
            return closeApp(named: name)
        case .switchApp:
            guard let name = decision.targetApp else { throw ExecutorError.missingSlot("target app") }
            return try await switchApp(named: name)
        case .minimizeApp:
            guard let name = decision.targetApp else { throw ExecutorError.missingSlot("target app") }
            return try minimizeApp(named: name)
        case .hideApp:
            guard let name = decision.targetApp else { throw ExecutorError.missingSlot("target app") }
            return hideApp(named: name)
        case .openURL:
            guard let urlString = decision.url, let url = URL(string: urlString) else {
                throw ExecutorError.missingSlot("url")
            }
            return try await open(url, browser: decision.targetApp)
        case .webSearch:
            guard let query = decision.query else { throw ExecutorError.missingSlot("query") }
            var components = URLComponents(string: "https://www.google.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            guard let url = components.url else { throw ExecutorError.missingSlot("query") }
            return try await open(url, browser: decision.targetApp)
        case .dictate:
            guard let text = decision.text else { throw ExecutorError.missingSlot("text") }
            return dictate(text)
        case .system:
            return try runSystem(decision.systemAction ?? .none, percent: decision.percent)
        case .none:
            return "No action"
        }
    }

    @MainActor
    private static func openApp(named name: String) async throws -> String {
        guard let url = InstalledApps.appURL(named: name) else {
            throw ExecutorError.appNotFound(name)
        }
        try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
        return "Opened \(name)"
    }

    private static func runningApp(named name: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame }
            ?? apps.first { $0.localizedName?.lowercased().contains(name.lowercased()) ?? false }
    }

    private static func closeApp(named name: String) -> String {
        guard let app = runningApp(named: name) else { return "\(name) is not running" }
        app.terminate()
        return "Quit \(app.localizedName ?? name)"
    }

    @MainActor
    private static func switchApp(named name: String) async throws -> String {
        if let app = runningApp(named: name) {
            app.unhide()
            app.activate(options: [.activateAllWindows])
            return "Switched to \(app.localizedName ?? name)"
        }
        return try await openApp(named: name)
    }

    private static func minimizeApp(named name: String) throws -> String {
        guard let app = runningApp(named: name) else { return "\(name) is not running" }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
        guard status == .success, let windows = windowsValue as? [AXUIElement] else {
            throw NSError(
                domain: "JevVoice.Executor", code: Int(status.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Cannot access windows of \(app.localizedName ?? name) (Accessibility permission?)"]
            )
        }
        for window in windows {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
        return "Minimized \(app.localizedName ?? name)"
    }

    private static func hideApp(named name: String) -> String {
        guard let app = runningApp(named: name) else { return "\(name) is not running" }
        app.hide()
        return "Hid \(app.localizedName ?? name)"
    }

    @MainActor
    private static func open(_ url: URL, browser: String?) async throws -> String {
        if let browser, let appURL = InstalledApps.appURL(named: browser) {
            try await NSWorkspace.shared.open(
                [url], withApplicationAt: appURL, configuration: .init()
            )
            return "Opened \(url.host ?? url.absoluteString) in \(browser)"
        }
        NSWorkspace.shared.open(url)
        return "Opened \(url.host ?? url.absoluteString)"
    }

    private static func dictate(_ text: String) -> String {
        let pasteboard = NSPasteboard.general
        let saved: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            DispatchQueue.main.async {
                guard pasteboard.changeCount == ourChangeCount else { return }
                pasteboard.clearContents()
                if !saved.isEmpty { pasteboard.writeObjects(saved) }
            }
        }
        return "Typed \"\(text)\""
    }

    private static func runSystem(_ action: SystemAction, percent: Int?) throws -> String {
        switch action {
        case .volumeSet:
            let level = percent ?? 50
            try osascript("set volume output volume \(level)")
            return "Volume \(level)%"
        case .mute:
            try osascript("set volume with output muted")
            return "Muted"
        case .unmute:
            try osascript("set volume without output muted")
            return "Unmuted"
        case .volumeUp:
            try osascript("set volume output volume (output volume of (get volume settings) + 10)")
            return "Volume up"
        case .volumeDown:
            try osascript("set volume output volume (output volume of (get volume settings) - 10)")
            return "Volume down"
        case .brightnessUp:
            try osascript(#"tell application "System Events" to key code 144"#)
            return "Brightness up"
        case .brightnessDown:
            try osascript(#"tell application "System Events" to key code 145"#)
            return "Brightness down"
        case .showDesktop:
            try osascript(#"tell application "System Events" to key code 103"#)
            return "Show desktop"
        case .lockScreen:
            try process("/usr/bin/pmset", ["displaysleepnow"])
            return "Locked"
        case .sleep:
            try process("/usr/bin/pmset", ["sleepnow"])
            return "Sleeping"
        case .screenshot:
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let path = NSHomeDirectory() + "/Desktop/jev-voice-\(stamp).png"
            try process("/usr/sbin/screencapture", ["-x", path])
            return "Screenshot saved to Desktop"
        case .none:
            return "No system action"
        }
    }

    @discardableResult
    private static func osascript(_ source: String) throws -> String {
        try process("/usr/bin/osascript", ["-e", source])
    }

    @discardableResult
    private static func process(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "JevVoice.Executor", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "\(launchPath) failed" : output]
            )
        }
        return output
    }
}
