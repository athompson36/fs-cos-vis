import Foundation
import Security

struct FeedbackBundleResult: Sendable {
    var bundleURL: URL
    var summary: String
}

/// Keychain-backed storage for feedback credentials (GitHub PAT + relay bearer). These are secrets
/// and must not live in the plaintext settings JSON (which is also served over `GET /api/settings`).
enum FeedbackSecretsKeychain {
    private static let service = "com.fsdmxvision.feedback.v1"
    static let githubTokenAccount = "githubToken"
    static let relayBearerAccount = "relayBearer"

    static func load(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    static func save(account: String, value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// JSON body for `POST` to a maintainer-hosted relay (server holds GitHub credentials).
private struct FeedbackRelayPayload: Encodable {
    var title: String
    var body: String
    var repository: String
    var appVersion: String
}

enum FeedbackAndLogsService {
    /// Returns a URL suitable for relay submission, or `nil` if `raw` is empty or not permitted (https only, or http on localhost for dev).
    static func parseFeedbackRelayURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        if scheme == "https" { return url }
        if scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            if host == "localhost" || host == "127.0.0.1" { return url }
        }
        return nil
    }
    static func createBundle(
        outputFolder: URL,
        message: String,
        appModel: AppModel
    ) throws -> FeedbackBundleResult {
        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = outputFolder.appendingPathComponent("feedback-\(ts)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let note = folder.appendingPathComponent("feedback.txt")
        try message.data(using: .utf8)?.write(to: note, options: .atomic)

        let ctx = folder.appendingPathComponent("machine_context.json")
        let snap = appModel.makeContextSnapshotForFeedback()
        let root = ShowContextGenerator.buildMachineRoot(from: snap)
        let payload = try ShowContextGenerator.encodeMachineJSON(root: root)
        try payload.write(to: ctx, options: .atomic)

        return FeedbackBundleResult(bundleURL: folder, summary: "Saved feedback bundle: \(folder.lastPathComponent)")
    }

    /// Submits feedback: uses **relay** when `relayURL` parses to a permitted URL (no GitHub PAT in the app); otherwise uses the GitHub API when `token` is set.
    static func submitFeedbackIssue(
        relayURL: String,
        relayBearer: String,
        repository: String,
        githubToken: String,
        title: String,
        body: String
    ) async throws {
        let relayRaw = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !relayRaw.isEmpty {
            guard let endpoint = parseFeedbackRelayURL(relayRaw) else {
                throw NSError(
                    domain: "FeedbackAndLogsService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Feedback relay URL must be https://, or http://localhost / http://127.0.0.1 for development."]
                )
            }
            try await submitViaRelay(endpoint: endpoint, bearer: relayBearer, title: title, body: body, repository: repository)
            return
        }
        try await submitGithubIssue(repository: repository, token: githubToken, title: title, body: body)
    }

    private static func submitViaRelay(
        endpoint: URL,
        bearer: String,
        title: String,
        body: String,
        repository: String
    ) async throws {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let trimmedBearer = bearer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBearer.isEmpty {
            req.setValue("Bearer \(trimmedBearer)", forHTTPHeaderField: "Authorization")
        }
        let payload = FeedbackRelayPayload(
            title: title,
            body: body,
            repository: repository,
            appVersion: AppBuildInfo.displayVersion
        )
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw NSError(domain: "FeedbackAndLogsService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Feedback relay rejected the request"])
        }
    }

    static func submitGithubIssue(
        repository: String,
        token: String,
        title: String,
        body: String
    ) async throws {
        guard !repository.isEmpty, !token.isEmpty else {
            throw NSError(
                domain: "FeedbackAndLogsService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Set a GitHub token for direct API submission, or configure a feedback relay URL (no GitHub token required)."]
            )
        }
        let url = URL(string: "https://api.github.com/repos/\(repository)/issues")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "title": title,
            "body": body,
            "labels": ["feedback", "beta-0.1a"],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw NSError(domain: "FeedbackAndLogsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "GitHub issue submission failed"])
        }
    }
}
