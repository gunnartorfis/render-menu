import Foundation

actor RenderAPIClient {
    private let baseURL = "https://api.render.com/v1"
    private var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Owners

    func fetchOwners() async throws -> [Owner] {
        var allOwners: [Owner] = []
        var cursor: String?

        repeat {
            var urlString = "\(baseURL)/owners?limit=100"
            if let cursor { urlString += "&cursor=\(cursor)" }

            let response: [OwnerResponse] = try await request(urlString)
            allOwners.append(contentsOf: response.map(\.owner))
            cursor = response.last?.cursor
        } while cursor != nil

        return allOwners
    }

    // MARK: - Services

    func fetchServices(ownerId: String) async throws -> [Service] {
        var allServices: [Service] = []
        var cursor: String?

        repeat {
            var urlString = "\(baseURL)/services?ownerId=\(ownerId)&limit=100&includePreviews=true"
            if let cursor { urlString += "&cursor=\(cursor)" }

            let response: [ServiceResponse] = try await request(urlString)
            allServices.append(contentsOf: response.map(\.service))
            cursor = response.last?.cursor
        } while cursor != nil

        return allServices
    }

    // MARK: - Deploys

    func fetchLatestDeploy(serviceId: String) async throws -> Deploy? {
        let urlString = "\(baseURL)/services/\(serviceId)/deploys?limit=1"
        let response: [DeployResponse] = try await request(urlString)
        return response.first?.deploy
    }

    // MARK: - Private

    private func request<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response"
        case .httpError(401): "Invalid API key"
        case .httpError(403): "Access denied"
        case .httpError(429): "Rate limited"
        case .httpError(let code): "HTTP error \(code)"
        }
    }
}
