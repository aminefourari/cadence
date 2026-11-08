import AppKit
import SwiftUI

@main
struct CadenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel
    @StateObject private var player: YouTubePlayerController

    init() {
        let player = YouTubePlayerController()
        _player = StateObject(wrappedValue: player)
        _model = StateObject(wrappedValue: AppModel(player: player))
    }

    var body: some Scene {
        Window("Cadence", id: "main") {
            RootView()
                .environmentObject(model)
                .environmentObject(player)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    model.openSettings(.updates)
                    Task { await Updater.shared.check() }
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Timer") {
                Button(model.timer.running ? "Pause Timer" : "Start Timer") {
                    model.requestTimerToggle()
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Reset Timer") {
                    model.resetTimer()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Skip Interval") {
                    model.skipTimer()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Focus") {
                    model.selectTab(.focus)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Tasks") {
                    model.selectTab(.tasks)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Music") {
                    model.selectTab(.music)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("History") {
                    model.selectTab(.history)
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("End the Day…") {
                    model.openShutdown()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Toggle Theme") {
                    model.toggleTheme()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarWidgetView()
                .environmentObject(model)
                .environmentObject(player)
        } label: {
            HStack(spacing: Theme.s(5)) {
                Circle()
                    .fill(model.timer.running ? Theme.accent : Theme.muted)
                    .frame(width: 5, height: 5)
                Text(model.timer.formattedRemaining)
                    .font(Theme.font(11, .medium, design: .monospaced))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            Updater.shared.installOnQuit()
        }
    }
}
