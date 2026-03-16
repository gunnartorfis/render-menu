import SwiftUI

@main
struct RenderMenuApp: App {
    @State private var appState = AppState()
    @State private var showSettings = false

    var body: some Scene {
        MenuBarExtra {
            menuContent
                .onAppear {
                    appState.loadFromKeychain()
                    if appState.isLoggedIn {
                        Task {
                            let owners = try? await RenderAPIClient(apiKey: appState.apiKey).fetchOwners()
                            if let owners {
                                appState.owners = owners
                                if let savedId = UserDefaults.standard.string(forKey: "selectedOwnerId"),
                                   let owner = owners.first(where: { $0.id == savedId }) {
                                    await appState.selectOwner(owner)
                                } else if let first = owners.first {
                                    await appState.selectOwner(first)
                                }
                            }
                            appState.startAutoRefresh()
                        }
                    }
                }
        } label: {
            Label("Render", systemImage: "cloud.fill")
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuContent: some View {
        if !appState.isLoggedIn {
            LoginView(state: appState)
        } else if showSettings {
            VStack(spacing: 0) {
                SettingsView(state: appState)
                Divider()
                HStack {
                    Button("← Back") { showSettings = false }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    Spacer()
                    quitButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        } else {
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
