import AppKit

/// Watches which app comes to the front while a focus interval runs and reports
/// apps on the user's distraction list. No extra permissions are needed.
final class FocusGuard {
    var isEnabled = false {
        didSet { refreshObservation() }
    }
    /// Lowercased app names, as shown in the Dock.
    var appNames: Set<String> = []
    var onDistraction: ((String) -> Void)?

    private var focusRunning = false
    private var observer: NSObjectProtocol?
    private var lastNudge: [String: Date] = [:]
    private let cooldown: TimeInterval = 120

    func update(focusRunning: Bool) {
        self.focusRunning = focusRunning
        if !focusRunning { lastNudge.removeAll() }
        refreshObservation()
    }

    private func refreshObservation() {
        let shouldObserve = isEnabled && focusRunning
        if shouldObserve, observer == nil {
            observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.handleActivation(of: app)
            }
        } else if !shouldObserve, let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func handleActivation(of app: NSRunningApplication?) {
        guard let name = app?.localizedName, appNames.contains(name.lowercased()) else { return }
        let now = Date()
        if let last = lastNudge[name], now.timeIntervalSince(last) < cooldown { return }
        lastNudge[name] = now
        onDistraction?(name)
    }
}

struct InstalledApp: Identifiable, Hashable {
    /// Matches `NSRunningApplication.localizedName`, which is what `FocusGuard` compares against.
    let name: String
    let url: URL?
    var id: String { name.lowercased() }
}

enum InstalledApps {
    /// Running apps plus everything in the standard Applications folders, sorted by name.
    static func scan() -> [InstalledApp] {
        let fm = FileManager.default
        let own = Bundle.main.bundleURL.standardizedFileURL
        var byID: [String: InstalledApp] = [:]
        func add(_ name: String, _ url: URL) {
            guard url.standardizedFileURL != own else { return }
            let app = InstalledApp(name: name, url: url)
            if byID[app.id] == nil { byID[app.id] = app }
        }
        // Running apps first: their localizedName is exactly what activation reports.
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let name = app.localizedName, let url = app.bundleURL { add(name, url) }
        }
        let roots = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        for root in roots {
            guard let walker = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in walker where url.pathExtension == "app" {
                var name = fm.displayName(atPath: url.path)
                if name.hasSuffix(".app") { name.removeLast(4) }
                add(name, url)
            }
        }
        return byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

enum ShortcutsLibrary {
    /// Names of the user's shortcuts from `shortcuts list`; empty if the CLI fails.
    static func names() async -> [String] {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            return String(decoding: data, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }.value
    }
}
