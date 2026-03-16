import SwiftUI

struct SettingsView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            apiKeySection
            workspaceSection
        }
        .padding(16)
        .frame(width: 280)
    }

    private var apiKeySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .font(.callout)
                    Spacer()
                    Text(maskedKey)
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

    private var maskedKey: String {
        let key = state.apiKey
        if key.count > 8 {
            return String(key.prefix(4)) + "..." + String(key.suffix(4))
        }
        return "••••"
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
