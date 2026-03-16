import SwiftUI

@MainActor
struct LoginView: View {
    let state: AppState

    @State private var apiKeyInput: String = ""
    @State private var githubTokenInput: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Render Menu")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Render API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("rnd_...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub Token (for PR titles)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("ghp_...", text: $githubTokenInput)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                login()
            } label: {
                if state.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.isEmpty || state.isLoading)

            HStack(spacing: 12) {
                Link("Render key",
                     destination: URL(string: "https://dashboard.render.com/account/api-keys")!)
                Link("GitHub token",
                     destination: URL(string: "https://github.com/settings/tokens")!)
            }
            .font(.caption)
        }
        .padding(20)
        .frame(width: 280)
    }

    private func login() {
        Task { await state.login(apiKey: apiKeyInput, githubToken: githubTokenInput) }
    }
}
