import Foundation

// MARK: - Owner / Workspace

struct OwnerResponse: Codable {
    let owner: Owner
    let cursor: String?
}

struct Owner: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let type: OwnerType

    enum OwnerType: String, Codable {
        case user
        case team
    }
}

// MARK: - Service

struct ServiceResponse: Codable {
    let service: Service
    let cursor: String?
}

struct Service: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let slug: String
    let repo: String?
    let suspended: String?
    let suspenders: [String]?
    let ownerId: String
    let createdAt: String
    let updatedAt: String
    let serviceDetails: ServiceDetails?
    let parentServer: ParentServer?

    var isPreview: Bool {
        name.range(of: #"PR #\d+"#, options: .regularExpression) != nil || parentServer != nil
    }

    var prNumber: Int? {
        guard let range = name.range(of: #"PR #(\d+)"#, options: .regularExpression) else { return nil }
        let match = String(name[range])
        return Int(match.replacingOccurrences(of: "PR #", with: ""))
    }

    var baseName: String {
        guard let range = name.range(of: #" PR #\d+"#, options: .regularExpression) else { return name }
        return String(name[name.startIndex..<range.lowerBound])
    }

    var previewURL: URL? {
        guard let urlString = serviceDetails?.url else { return nil }
        return URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)")
    }

    /// Parses "owner/repo" from the GitHub repo URL
    var gitHubRepo: String? {
        guard let repo else { return nil }
        // Handle https://github.com/owner/repo or git@github.com:owner/repo.git
        if repo.contains("github.com") {
            let cleaned = repo
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: ".git", with: "")
            let parts = cleaned.split(separator: "/")
            if parts.count >= 2 {
                return "\(parts[0])/\(parts[1])"
            }
        }
        return nil
    }

    var statusIndicator: ServiceStatus {
        if suspended == "suspended" || suspended == "not_running" {
            return .suspended
        }
        if let suspenders, !suspenders.isEmpty {
            return .suspended
        }
        return .live
    }
}

struct ServiceDetails: Codable {
    let url: String?
    let buildCommand: String?
    let pullRequestPreviewsEnabled: String?
}

struct ParentServer: Codable {
    let id: String?
    let name: String?
}

enum ServiceStatus {
    case live
    case deploying
    case failed
    case suspended

    var color: String {
        switch self {
        case .live: "green"
        case .deploying: "yellow"
        case .failed: "red"
        case .suspended: "gray"
        }
    }

    var sfSymbol: String {
        switch self {
        case .live: "circle.fill"
        case .deploying: "arrow.triangle.2.circlepath"
        case .failed: "xmark.circle.fill"
        case .suspended: "pause.circle.fill"
        }
    }
}

// MARK: - GitHub PR

struct GitHubPR: Codable {
    let number: Int
    let title: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case number, title
        case htmlUrl = "html_url"
    }
}

// MARK: - Deploy

struct DeployResponse: Codable {
    let deploy: Deploy
    let cursor: String?
}

struct Deploy: Codable, Identifiable {
    let id: String
    let status: String?

    var deployStatus: ServiceStatus {
        switch status {
        case "live": .live
        case "build_in_progress", "update_in_progress", "pre_deploy_in_progress": .deploying
        case "build_failed", "update_failed", "pre_deploy_failed", "canceled", "deactivated": .failed
        default: .suspended
        }
    }
}
