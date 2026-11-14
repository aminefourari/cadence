import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts that work while another app is in front. Carbon hot keys need
/// no Accessibility permission, unlike a global event monitor.
@MainActor
final class GlobalHotKeys {
    struct Binding {
        let keyCode: Int
        let symbol: String
        let title: String
        let action: @MainActor () -> Void
    }

    static let shared = GlobalHotKeys()
    /// ⌃⌥ on every binding: rarely taken by other apps.
    static let modifierSymbols = "⌃⌥"
    private static let modifiers = UInt32(controlKey | optionKey)
    private static let signature: OSType = 0x4344_4E43 // "CDNC"

    private(set) var bindings: [Binding] = []
    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? registerAll() : unregisterAll()
        }
    }

    func configure(_ bindings: [Binding]) {
        unregisterAll()
        self.bindings = bindings
        if isEnabled { registerAll() }
    }

    private func registerAll() {
        installHandlerIfNeeded()
        for (index, binding) in bindings.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode), Self.modifiers, id, GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                refs.append(ref)
            } else {
                NSLog("[Cadence] \(Self.modifierSymbols)\(binding.symbol) is taken by another app (\(status)).")
            }
        }
    }

    private func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr, id.signature == GlobalHotKeys.signature else { return OSStatus(eventNotHandledErr) }
            let index = Int(id.id)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let bindings = GlobalHotKeys.shared.bindings
                    if bindings.indices.contains(index) { bindings[index].action() }
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
