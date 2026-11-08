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
