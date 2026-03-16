import SwiftUI

struct PreviewListView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Workspace switcher
            if state.owners.count > 1 {
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

                Divider()
            }

            // Content
            if state.isLoading && state.previewServices.isEmpty {
                loadingView
            } else if state.previewServices.isEmpty {
                emptyView
            } else {
                previewList
            }

            // Footer
            footerView
        }
        .frame(width: 320)
    }

    // MARK: - Subviews

    private var previewList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.previewServices) { service in
                    PreviewRowView(service: service, status: state.statusFor(service))
                    if service.id != state.previewServices.last?.id {
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

    var body: some View {
        Button {
            if let url = service.previewURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: status.sfSymbol)
                    .foregroundStyle(statusColor)
                    .font(.caption)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(service.baseName)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let pr = service.prNumber {
                            Text("#\(pr)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let url = service.serviceDetails?.url {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
