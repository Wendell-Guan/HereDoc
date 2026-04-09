import Foundation
import HereDocAI

struct ProviderSettingsSnapshot: Codable {
    var profiles: [AIProviderProfile]
    var selectedProviderID: UUID?
}

struct ProviderSettingsStore {
    private let defaults: UserDefaults
    private let key = "HereDoc.provider-settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ProviderSettingsSnapshot {
        guard
            let data = defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(ProviderSettingsSnapshot.self, from: data),
            snapshot.profiles.isEmpty == false
        else {
            let profiles = defaultProfiles()
            return ProviderSettingsSnapshot(
                profiles: profiles,
                selectedProviderID: profiles.first?.id
            )
        }

        return snapshot
    }

    func save(_ snapshot: ProviderSettingsSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: key)
    }

    func defaultProfiles() -> [AIProviderProfile] {
        [
            AIProviderProfile(
                name: "OpenAI 官方",
                kind: .openAI,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                model: "gpt-4o-mini",
                credentialSource: .keychain(account: "provider.openai.official.api_key"),
                supportsStructuredOutput: true,
                supportsVision: true
            ),
            AIProviderProfile(
                name: "OpenAI 兼容中转",
                kind: .openAICompatible,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                model: "gpt-4o-mini",
                credentialSource: .keychain(account: "provider.openai.compatible.api_key"),
                supportsStructuredOutput: true,
                supportsVision: true
            )
        ]
    }

    func makeKeychainAccount(for profileID: UUID) -> String {
        "provider.\(profileID.uuidString.lowercased()).api_key"
    }
}
