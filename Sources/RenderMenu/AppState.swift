import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var apiKey: String = ""
    var githubToken: String = ""
    var githubUsername: String = ""
    var isLoggedIn: Bool = false
    var owners: [Owner] = []
    var selectedOwner: Owner?
    var previewServices: [Service] = []
    var deployStatuses: [String: ServiceStatus] = [:]
    var prInfo: [String: GitHubPR] = [:]
    var showOnlyMine: Bool = true
    var unseenCount: Int = 0
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    @ObservationIgnored
    @AppStorage("selectedOwnerId") private var savedOwnerId: String = ""

    private var apiClient: RenderAPIClient?
    private var githubClient: GitHubAPIClient?
    private var refreshTimer: Timer?

    var hasGitHub: Bool { !githubToken.isEmpty }

    var filteredServices: [Service] {
        guard showOnlyMine, hasGitHub, !githubUsername.isEmpty else {
            return previewServices
        }
        if prInfo.isEmpty {
            return previewServices
        }
        return previewServices.filter { service in
            guard let pr = prInfo[service.id] else { return true }
            return pr.user.login == githubUsername
        }
    }

    // MARK: - Auth

    func loadFromKeychain() {
        guard let creds = KeychainService.load() else { return }
        if !creds.renderAPIKey.isEmpty {
            apiKey = creds.renderAPIKey
            isLoggedIn = true
            apiClient = RenderAPIClient(apiKey: creds.renderAPIKey)
        }
        if !creds.githubToken.isEmpty {
            githubToken = creds.githubToken
            githubClient = GitHubAPIClient(token: creds.githubToken)
        }
    }

    private func saveCredentials() {
        _ = KeychainService.save(StoredCredentials(
            renderAPIKey: apiKey,
            githubToken: githubToken
        ))
    }

    func login(apiKey key: String, githubToken ghToken: String = "") async {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        apiClient = RenderAPIClient(apiKey: trimmedKey)
        isLoading = true
        errorMessage = nil

        do {
            let fetchedOwners = try await apiClient!.fetchOwners()
            apiKey = trimmedKey
            isLoggedIn = true
            owners = fetchedOwners

            let trimmedGH = ghToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedGH.isEmpty {
                githubToken = trimmedGH
                githubClient = GitHubAPIClient(token: trimmedGH)
            }

            saveCredentials()

            await resolveGitHubUser()

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
        githubToken = trimmed
        githubClient = GitHubAPIClient(token: trimmed)
        saveCredentials()
        Task {
            await resolveGitHubUser()
            await fetchPRInfo()
        }
    }

    func logout() {
        KeychainService.delete()
        apiKey = ""
        githubToken = ""
        githubUsername = ""
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
            let previews = services.filter(\.isPreview).sorted { $0.updatedAt > $1.updatedAt }
            previewServices = previews
            isLoading = false
            lastUpdated = Date()

            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await self.fetchDeployStatuses(previews: previews, client: client)
                }
                group.addTask { @MainActor in
                    await self.fetchPRInfo()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func resolveGitHubUser() async {
        guard let gh = githubClient else { return }
        if let user = try? await gh.fetchCurrentUser() {
            githubUsername = user.login
        }
    }

    private func fetchDeployStatuses(previews: [Service], client: RenderAPIClient) async {
        let oldStatuses = deployStatuses

        await withTaskGroup(of: (String, ServiceStatus).self) { group in
            for service in previews {
                group.addTask {
                    if let deploy = try? await client.fetchLatestDeploy(serviceId: service.id) {
                        return (service.id, deploy.deployStatus)
                    }
                    return (service.id, service.statusIndicator)
                }
            }

            for await (id, status) in group {
                if let old = oldStatuses[id], old != .live, status == .live {
                    unseenCount += 1
                    sendNotification(for: previews.first { $0.id == id })
                }
                deployStatuses[id] = status
            }
        }
    }

    private func sendNotification(for service: Service?) {
        // UNUserNotificationCenter requires a proper app bundle.
        // For now, just increment the unseen badge count.
        // TODO: Add NSUserNotification or migrate to .app bundle for push notifications.
    }

    func clearUnseen() {
        unseenCount = 0
    }

    private func fetchPRInfo() async {
        guard let gh = githubClient else { return }
        for service in previewServices {
            guard let repo = service.gitHubRepo, let pr = service.prNumber else { continue }
            if let result = try? await gh.fetchPR(repo: repo, number: pr) {
                prInfo[service.id] = result
            }
        }
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
