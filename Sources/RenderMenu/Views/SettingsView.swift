import SwiftUI

@MainActor
struct SettingsView: View {
    let state: AppState
    @State private var githubTokenInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            apiKeySection
            githubSection
            workspaceSection
        }
        .padding(16)
        .frame(width: 280)
    }

    private var apiKeySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Render API Key")
                        .font(.callout)
                    Spacer()
                    Text(mask(state.apiKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Logout", role: .destructive) {
                    state.logout()
                }
            }
            .padding(4)
        }
    }

    private var githubSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("GitHub Token")
                        .font(.callout)
                    Spacer()
                    if state.hasGitHub {
                        Text(mask(state.githubToken))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if state.hasGitHub {
                    Text("PR titles enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        SecureField("ghp_...", text: $githubTokenInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Save") {
                            state.saveGitHubToken(githubTokenInput)
                            githubTokenInput = ""
                        }
                        .disabled(githubTokenInput.isEmpty)
                    }
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var workspaceSection: some View {
        if !state.owners.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace")
                        .font(.callout)

                    ForEach(state.owners) { owner in
                        OwnerRowButton(owner: owner, isSelected: owner.id == state.selectedOwner?.id) {
                            Task { await state.selectOwner(owner) }
                        }
                    }
                }
                .padding(4)
            }
        }
    }

    private func mask(_ key: String) -> String {
        if key.count > 8 {
            return String(key.prefix(4)) + "..." + String(key.suffix(4))
        }
        return "****"
    }
}

private struct OwnerRowButton: View {
    let owner: Owner
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: owner.type == .team ? "person.2" : "person")
                    .frame(width: 20)
                Text(owner.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
