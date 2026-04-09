import Foundation

public actor AIProviderRegistry {
    private var providers: [UUID: any AIProvider] = [:]

    public init() {}

    public func register(_ provider: any AIProvider) {
        providers[provider.profile.id] = provider
    }

    public func allProfiles() -> [AIProviderProfile] {
        providers.values.map(\.profile).sorted { $0.name < $1.name }
    }

    public func provider(for workload: AIWorkload, preferredID: UUID? = nil) -> (any AIProvider)? {
        if let preferredID, let provider = providers[preferredID], provider.canHandle(workload) {
            return provider
        }

        return providers.values.first { $0.canHandle(workload) }
    }
}
