import Foundation

struct FeedbackBundleResult: Sendable {
    var bundleURL: URL
    var summary: String
}

enum FeedbackAndLogsService {
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

    static func submitGithubIssue(
        repository: String,
        token: String,
        title: String,
        body: String
    ) async throws {
        guard !repository.isEmpty, !token.isEmpty else { return }
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
