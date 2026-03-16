import Foundation

actor GitHubAPIClient {
    private var token: String
    private var cache: [String: GitHubPR] = [:]

    init(token: String) {
        self.token = token
    }

    func updateToken(_ token: String) {
        self.token = token
        cache.removeAll()
    }

    /// Fetch PR info. Cache key: "owner/repo#number"
    func fetchPR(repo: String, number: Int) async throws -> GitHubPR {
        let cacheKey = "\(repo)#\(number)"
        if let cached = cache[cacheKey] { return cached }

        let url = URL(string: "https://api.github.com/repos/\(repo)/pulls/\(number)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()
        let pr = try decoder.decode(GitHubPR.self, from: data)
        cache[cacheKey] = pr
        return pr
    }

    /// Batch fetch PR titles for multiple services. Returns [serviceId: GitHubPR]
    func fetchPRs(for services: [Service]) async -> [String: GitHubPR] {
        await withTaskGroup(of: (String, GitHubPR?).self) { group in
            for service in services {
                guard let repo = service.gitHubRepo, let pr = service.prNumber else { continue }
                group.addTask {
                    let result = try? await self.fetchPR(repo: repo, number: pr)
                    return (service.id, result)
                }
            }

            var results: [String: GitHubPR] = [:]
            for await (id, pr) in group {
                if let pr { results[id] = pr }
            }
            return results
        }
    }
}
