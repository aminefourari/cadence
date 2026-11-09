import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: YouTubePlayerController
    @State private var visitedMusic = false

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            HStack(spacing: 0) {
                SidebarView()

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)

                ZStack {
                    FocusView()
                        .opacity(model.selectedTab == .focus ? 1 : 0)
                        .allowsHitTesting(model.selectedTab == .focus)
                        .accessibilityHidden(model.selectedTab != .focus)

                    TasksView()
                        .opacity(model.selectedTab == .tasks ? 1 : 0)
                        .allowsHitTesting(model.selectedTab == .tasks)
                        .accessibilityHidden(model.selectedTab != .tasks)

                    HistoryView()
                        .opacity(model.selectedTab == .history ? 1 : 0)
                        .allowsHitTesting(model.selectedTab == .history)
                        .accessibilityHidden(model.selectedTab != .history)

                    if visitedMusic {
                        MusicView()
                            .opacity(model.selectedTab == .music ? 1 : 0)
                            .allowsHitTesting(model.selectedTab == .music)
                            .accessibilityHidden(model.selectedTab != .music)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // Pages swap instantly; a cross-fade leaves the old page lingering.
                .animation(nil, value: model.selectedTab)
            }
            .ignoresSafeArea()

            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.top, Theme.s(20))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(30)
            }

            if model.showIntentionPrompt {
                IntentionCheckInView()
                    .environmentObject(model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(40)
            }

            if model.showShutdown {
                ShutdownRitualView()
                    .environmentObject(model)
                    .environmentObject(player)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(50)
            }

            if ProcessInfo.processInfo.arguments.contains("--settings-overlay") {
                Theme.inkDeep.opacity(0.55)
                    .ignoresSafeArea()
                    .zIndex(60)

                SettingsView()
                    .environmentObject(model)
                    .environmentObject(player)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius(18), style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radius(18), style: .continuous)
                            .strokeBorder(Theme.controlStroke, lineWidth: 1)
                    }
                    .shadow(color: Theme.shadow, radius: 34, x: 0, y: 18)
                    .zIndex(61)
            }

            if ProcessInfo.processInfo.arguments.contains("--widget-overlay") {
                Theme.inkDeep.opacity(0.45)
                    .ignoresSafeArea()
                    .zIndex(70)

                MenuBarWidgetView()
                    .environmentObject(model)
                    .environmentObject(player)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                            .strokeBorder(Theme.controlStroke, lineWidth: 1)
                    }
                    .shadow(color: Theme.shadow, radius: 30, x: 0, y: 16)
                    .zIndex(71)
            }
        }
        .frame(minWidth: 980, minHeight: 720)
        .background(WindowConfigurator())
        .preferredColorScheme(model.appearanceMode.colorScheme)
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .environmentObject(model)
                .environmentObject(player)
        }
        .onAppear {
            if model.selectedTab == .music {
                visitedMusic = true
            }
        }
        .onChange(of: model.selectedTab) { _, tab in
            if tab == .music {
                visitedMusic = true
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.themeMode)
        .animation(.easeInOut(duration: 0.28), value: model.appearanceMode)
        .animation(.easeInOut(duration: 0.35), value: model.backgroundStyle)
        .animation(.easeInOut(duration: 0.22), value: model.selectedTab)
    }
}
