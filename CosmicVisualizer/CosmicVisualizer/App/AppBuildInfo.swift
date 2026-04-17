import Foundation

enum AppBuildInfo {
    static let betaLabel = "beta 0.1a"

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var displayVersion: String {
        "\(betaLabel) (\(shortVersion) build \(buildNumber))"
    }
}
