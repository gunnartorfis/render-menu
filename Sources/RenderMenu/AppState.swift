import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var apiKey: String = ""
    var githubToken: String = ""
    var isLoggedIn: Bool = false
    var owners: [Owner] = []
    var selectedOwner: Owner?
    var previewServices: [Service] = []
    var deployStatuses: [String: ServiceStatus] = [:]
    var prInfo: [String: GitHubPR] = [:]
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    @ObservationIgnored
    @AppStorage("selectedOwnerId") private var savedOwnerId: String = ""

    private var apiClient: RenderAPIClient?
    private var githubClient: GitHubAPIClient?
    private var refreshTimer: Timer?

    var hasGitHub: Bool { !githubToken.isEmpty }

    // MARK: - Auth

    func loadFromKeychain() {
        if let key = KeychainService.load(.renderAPIKey), !key.isEmpty {
            apiKey = key
            isLoggedIn = true
            apiClient = RenderAPIClient(apiKey: key)
        }
        if let token = KeychainService.load(.githubToken), !token.isEmpty {
            githubToken = token
            githubClient = GitHubAPIClient(token: token)
        }
    }

    func login(apiKey key: String, githubToken ghToken: String = "") async {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        apiClient = RenderAPIClient(apiKey: trimmedKey)
        isLoading = true
        errorMessage = nil

        do {
            let fetchedOwners = try await apiClient!.fetchOwners()
            _ = KeychainService.save(.renderAPIKey, value: trimmedKey)
            apiKey = trimmedKey
            isLoggedIn = true
            owners = fetchedOwners

            // Save GitHub token if provided
            let trimmedGH = ghToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedGH.isEmpty {
                _ = KeychainService.save(.githubToken, value: trimmedGH)
                githubToken = trimmedGH
                githubClient = GitHubAPIClient(token: trimmedGH)
            }

            if let saved = owners.first(where: { $0.id == savedOwnerId }) {
                selectedOwner = saved
            } else {
                selectedOwner = owners.first
            }
            if let selectedOwner {
                savedOwnerId = selectedOwner.id
            }
            await refreshPreviews()
        } catch {
            errorMessage = error.localizedDescription
            apiClient = nil
        }

        isLoading = false
    }

    func saveGitHubToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = KeychainService.save(.githubToken, value: trimmed)
        githubToken = trimmed
        githubClient = GitHubAPIClient(token: trimmed)
        // Re-fetch PR info with new token
        Task { await fetchPRInfo() }
    }

    func logout() {
        KeychainService.deleteAll()
        apiKey = ""
        githubToken = ""
        isLoggedIn = false
        owners = []
        selectedOwner = nil
        previewServices = []
        deployStatuses = [:]
        prInfo = [:]
        apiClient = nil
        githubClient = nil
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

            // Fetch GitHub PR info
            await fetchPRInfo()

            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchPRInfo() async {
        guard let gh = githubClient else { return }
        let results = await gh.fetchPRs(for: previewServices)
        prInfo = results
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

    func prTitleFor(_ service: Service) -> String? {
        prInfo[service.id]?.title
    }

    func prURLFor(_ service: Service) -> URL? {
        guard let urlString = prInfo[service.id]?.htmlUrl else { return nil }
        return URL(string: urlString)
    }
}
