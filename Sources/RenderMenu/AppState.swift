import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var apiKey: String = ""
    var isLoggedIn: Bool = false
    var owners: [Owner] = []
    var selectedOwner: Owner?
    var previewServices: [Service] = []
    var deployStatuses: [String: ServiceStatus] = [:]
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    @ObservationIgnored
    @AppStorage("selectedOwnerId") private var savedOwnerId: String = ""

    private var apiClient: RenderAPIClient?
    private var refreshTimer: Timer?

    var isSetUp: Bool { isLoggedIn && selectedOwner != nil }

    // MARK: - Auth

    func loadFromKeychain() {
        if let key = KeychainService.load(), !key.isEmpty {
            apiKey = key
            isLoggedIn = true
            apiClient = RenderAPIClient(apiKey: key)
        }
    }

    func login(apiKey key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        apiClient = RenderAPIClient(apiKey: trimmed)
        isLoading = true
        errorMessage = nil

        do {
            let fetchedOwners = try await apiClient!.fetchOwners()
            if KeychainService.save(apiKey: trimmed) {
                apiKey = trimmed
                isLoggedIn = true
                owners = fetchedOwners

                if let savedId = owners.first(where: { $0.id == savedOwnerId }) {
                    selectedOwner = savedId
                } else {
                    selectedOwner = owners.first
                }
                if let selectedOwner {
                    savedOwnerId = selectedOwner.id
                }
                await refreshPreviews()
            }
        } catch {
            errorMessage = error.localizedDescription
            apiClient = nil
        }

        isLoading = false
    }

    func logout() {
        KeychainService.delete()
        apiKey = ""
        isLoggedIn = false
        owners = []
        selectedOwner = nil
        previewServices = []
        deployStatuses = [:]
        apiClient = nil
        savedOwnerId = ""
        stopAutoRefresh()
    }

    // MARK: - Workspace

    func selectOwner(_ owner: Owner) async {
        selectedOwner = owner
        savedOwnerId = owner.id
        await refreshPreviews()
    }

    // MARK: - Data

    func refreshPreviews() async {
        guard let client = apiClient, let owner = selectedOwner else { return }
        isLoading = true
        errorMessage = nil

        do {
            let services = try await client.fetchServices(ownerId: owner.id)
            let previews = services.filter(\.isPreview)
            previewServices = previews.sorted { $0.updatedAt > $1.updatedAt }

            // Fetch deploy statuses concurrently
            await withTaskGroup(of: (String, ServiceStatus).self) { group in
                for service in previews {
                    group.addTask {
                        if let deploy = try? await client.fetchLatestDeploy(serviceId: service.id) {
                            return (service.id, deploy.deployStatus)
                        }
                        return (service.id, service.statusIndicator)
                    }
                }

                var statuses: [String: ServiceStatus] = [:]
                for await (id, status) in group {
                    statuses[id] = status
                }
                deployStatuses = statuses
            }

            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshPreviews()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Helpers

    func statusFor(_ service: Service) -> ServiceStatus {
        deployStatuses[service.id] ?? service.statusIndicator
    }
}
