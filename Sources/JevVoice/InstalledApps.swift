import AppKit

enum InstalledApps {
    static let searchDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    static func all() -> [String] {
        var names = Set<String>()
        let fm = FileManager.default
        for dir in searchDirectories {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "app" {
                names.insert(url.deletingPathExtension().lastPathComponent)
            }
        }
        for app in NSWorkspace.shared.runningApplications {
            if let name = app.localizedName { names.insert(name) }
        }
        return Array(names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(254))
    }

    static func appURL(named name: String) -> URL? {
        let fm = FileManager.default
        for dir in searchDirectories {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            if let exact = entries.first(where: {
                $0.pathExtension == "app" &&
                $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(name) == .orderedSame
            }) {
                return exact
            }
            if let prefix = entries.first(where: {
                $0.pathExtension == "app" &&
                $0.deletingPathExtension().lastPathComponent.lowercased().hasPrefix(name.lowercased())
            }) {
                return prefix
            }
        }
        return nil
    }
}
