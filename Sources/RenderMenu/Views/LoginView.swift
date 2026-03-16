import SwiftUI

struct LoginView: View {
    let state: AppState

    @State private var apiKeyInput: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Render Menu")
                .font(.headline)

            Text("Enter your Render API key")
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("rnd_...", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { login() }

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

            Link("Get API key from Render →",
                 destination: URL(string: "https://dashboard.render.com/account/api-keys")!)
                .font(.caption)
        }
        .padding(20)
        .frame(width: 280)
    }

    private func login() {
        Task { await state.login(apiKey: apiKeyInput) }
    }
}
