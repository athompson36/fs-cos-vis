import Foundation

struct ShowDirectorExecutionLogReadResult: Equatable, Sendable {
    var entries: [ExecutionLogEntry]
    var warnings: [String]
}

enum ShowDirectorExecutionLogStore {
    static func append(
        _ entry: ExecutionLogEntry,
        to packageRoot: URL,
        fileManager: FileManager = .default
    ) throws {
        let url = ShowDirectorPackageLayout.executionLogURL(in: packageRoot)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var data = try ShowDirectorJSON.makeCompactEncoder().encode(entry)
        data.append(contentsOf: "\n".utf8)

        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    static func read(from packageRoot: URL) throws -> ShowDirectorExecutionLogReadResult {
        let url = ShowDirectorPackageLayout.executionLogURL(in: packageRoot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ShowDirectorExecutionLogReadResult(entries: [], warnings: [])
        }

        let raw = try String(contentsOf: url, encoding: .utf8)
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var entries: [ExecutionLogEntry] = []
        var warnings: [String] = []
        let decoder = ShowDirectorJSON.makeDecoder()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            guard let data = trimmed.data(using: .utf8) else {
                if index == lines.count - 1 {
                    warnings.append("Ignored malformed final log line.")
                    continue
                }
                throw ShowDirectorPackageStoreError.replacementFailed(
                    "Malformed execution log line at index \(index)."
                )
            }
            do {
                entries.append(try decoder.decode(ExecutionLogEntry.self, from: data))
            } catch {
                if index == lines.count - 1 {
                    warnings.append("Ignored malformed final log line.")
                } else {
                    throw error
                }
            }
        }
        return ShowDirectorExecutionLogReadResult(entries: entries, warnings: warnings)
    }
}
