import SwiftUI

@main
struct RenderMenuApp: App {
    @State private var appState = AppState()
    @State private var showSettings = false
    @State private var hasInitialized = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            menuContent
                .task {
                    guard !hasInitialized else { return }
                    hasInitialized = true
                    appState.loadFromKeychain()
                    if appState.isLoggedIn {
                        await appState.login(apiKey: appState.apiKey)
                        appState.startAutoRefresh()
                    }
                }
                .onAppear {
                    appState.clearUnseen()
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: appState.unseenCount > 0 ? "cloud.fill" : "cloud")
            if appState.unseenCount > 0 {
                Text("\(appState.unseenCount)")
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if !appState.isLoggedIn {
            LoginView(state: appState)
        } else if showSettings {
            settingsContent
        } else {
            mainContent
        }
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
