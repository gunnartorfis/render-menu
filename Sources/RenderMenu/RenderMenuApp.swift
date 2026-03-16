import SwiftUI

@main
@MainActor
struct RenderMenuApp: App {
    @State private var appState = AppState()
    @State private var showSettings = false
    @State private var hasInitialized = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            // Stable container — never changes identity, so .task is never cancelled
            VStack(spacing: 0) {
                if !appState.isLoggedIn {
                    LoginView(state: appState)
                } else if showSettings {
                    settingsContent
                } else {
                    mainContent
                }
            }
            .task {
                guard !hasInitialized || !appState.isLoggedIn else { return }
                hasInitialized = true
                await initialize()
            }
            .onAppear {
                appState.requestNotificationPermission()
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private func initialize() async {
        appState.loadFromKeychain()
        if appState.isLoggedIn {
            await appState.login(apiKey: appState.apiKey, githubToken: appState.githubToken)
            appState.startAutoRefresh()
        }
    }

    private var menuBarLabel: some View {
        Image(systemName: "cloud")
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            PreviewListView(state: appState)
            Divider()
            HStack {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                quitButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 0) {
            SettingsView(state: appState)
            Divider()
            HStack {
                Button("Back") { showSettings = false }
                    .buttonStyle(.borderless)
                    .font(.caption)
                Spacer()
                quitButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var quitButton: some View {
        Button("Quit") {
            appState.stopAutoRefresh()
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
