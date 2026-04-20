import Foundation

struct AIProviderInfo: Equatable, Sendable {
    var providerID: String

    init(providerID: String) {
        self.providerID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isAnthropic: Bool { providerID == "anthropic" || providerID == "claude" }
    var displayName: String { isAnthropic ? "Claude (Anthropic)" : "OpenAI-compatible" }
    var apiWebsite: String {
        isAnthropic
            ? "https://www.anthropic.com/api"
            : "https://platform.openai.com/docs/api-reference"
    }
    var defaultBaseURLHint: String {
        isAnthropic
            ? "Base URL (empty = https://api.anthropic.com/v1/messages)"
            : "Base URL (empty = OpenAI-compatible default)"
    }
    var setupSteps: [String] {
        if isAnthropic {
            return [
                "Create an Anthropic API key in the Anthropic Console.",
                "Paste the key into this wizard and save it to Keychain.",
                "Use a Claude model id (example: claude-3-5-sonnet-latest).",
            ]
        }
        return [
            "Create an API key with your OpenAI-compatible provider.",
            "Paste the key into this wizard and save it to Keychain.",
            "Set model/base URL to match your provider if not default OpenAI.",
        ]
    }
}
