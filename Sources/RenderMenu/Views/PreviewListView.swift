import SwiftUI

@MainActor
struct PreviewListView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Workspace switcher
            if state.owners.count > 1 {
                workspaceSwitcher
                Divider()
            }

            // Filter toggle
            if state.hasGitHub {
                filterBar
                Divider()
            }

            // Content
            if state.isLoading && state.previewServices.isEmpty {
                loadingView
            } else if state.filteredServices.isEmpty {
                emptyView
            } else {
                previewList
            }

            // Footer
            footerView
        }
        .frame(width: 340)
    }

    // MARK: - Subviews

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterButton(label: "Mine", active: state.showOnlyMine) {
                state.showOnlyMine = true
            }
            filterButton(label: "All", active: !state.showOnlyMine) {
                state.showOnlyMine = false
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func filterButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(active ? .semibold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(active ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var workspaceSwitcher: some View {
        Menu {
            ForEach(state.owners) { owner in
                Button {
                    Task { await state.selectOwner(owner) }
                } label: {
                    HStack {
                        Text(owner.name)
                        if owner.id == state.selectedOwner?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: state.selectedOwner?.type == .team ? "person.2" : "person")
                    .foregroundStyle(.secondary)
                Text(state.selectedOwner?.name ?? "Select workspace")
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var previewList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.filteredServices) { service in
                    PreviewRowView(
                        service: service,
                        status: state.statusFor(service),
                        prTitle: state.prTitleFor(service),
                        prURL: state.prURLFor(service)
                    )
                    if service.id != state.filteredServices.last?.id {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Loading previews...")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(20)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No PR previews found")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private var footerView: some View {
        HStack {
            if let lastUpdated = state.lastUpdated {
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if state.isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
            Button {
                Task { await state.refreshPreviews() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(state.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct PreviewRowView: View {
    let service: Service
    let status: ServiceStatus
    let prTitle: String?
    let prURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main click area: open preview URL
            Button {
                if let url = service.previewURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                mainContent
            }
            .buttonStyle(.plain)

            // GitHub PR link button
            if let prURL {
                Button {
                    NSWorkspace.shared.open(prURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
                .help("Open PR on GitHub")
            }
        }
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.sfSymbol)
                .foregroundStyle(statusColor)
                .font(.caption)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                // Title: PR title if available, otherwise service name
                if let prTitle {
                    Text(prTitle)
                        .fontWeight(.medium)
                        .lineLimit(2)
                } else {
                    Text(service.baseName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                // Subtitle: service name + PR number
                HStack(spacing: 4) {
                    Text(service.baseName)
                        .foregroundStyle(.secondary)
                    if let pr = service.prNumber {
                        Text("#\(pr)")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)

                // URL
                if let url = service.serviceDetails?.url {
                    Text(url)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch status {
        case .live: .green
        case .deploying: .orange
        case .failed: .red
        case .suspended: .gray
        }
    }
}
